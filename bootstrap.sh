#!/usr/bin/env sh
set -eu

DOTFILES_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
HOME_DIR="${HOME:?HOME is required}"
THEMES_DIR="$DOTFILES_DIR/themes"
THEME="${THEME:-}"
ASSUME_YES=0
THEME_ONLY=0

log() {
  printf '%s\n' "$*"
}

usage() {
  cat <<EOF
Usage: ./bootstrap.sh [--theme THEME] [--yes] [--theme-only]
  --theme THEME   Apply a specific theme directly
  --yes           Non-interactive (defaults to night-owl when theme not set)
  --theme-only    Only apply theme links; skip core dotfile links
EOF
}

require_theme_assets() {
  chosen="$1"
  for rel in alacritty.toml tmux.conf nvim-theme.lua; do
    if [ ! -f "$THEMES_DIR/$chosen/$rel" ]; then
      log "error: missing theme asset: $THEMES_DIR/$chosen/$rel"
      exit 1
    fi
  done
}

is_light_theme() {
  case "$1" in
    *light*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

update_claude_theme() {
  config_file="$DOTFILES_DIR/claude/config.json"
  desired_theme="$1"

  if [ ! -f "$config_file" ]; then
    log "skip (missing source): $config_file"
    return 0
  fi

  tmp_file="$(mktemp)"
  if awk -v theme="$desired_theme" '
    BEGIN { saw_theme = 0; inserted = 0 }
    {
      if ($0 ~ /^  "theme"[[:space:]]*:[[:space:]]*"/) {
        if (!saw_theme) {
          print "  \"theme\": \"" theme "\","
          saw_theme = 1
        }
        next
      }
      if (!saw_theme && !inserted && $0 ~ /^[[:space:]]*{[[:space:]]*$/) {
        print
        print "  \"theme\": \"" theme "\","
        inserted = 1
        saw_theme = 1
        next
      }
      print
    }
    END {
      if (!saw_theme) {
        exit 1
      }
    }
  ' "$config_file" >"$tmp_file"; then
    mv "$tmp_file" "$config_file"
    log "updated: $config_file (.theme = $desired_theme)"
  else
    rm -f "$tmp_file"
    log "warn: could not update theme in $config_file"
  fi
}

choose_theme() {
  if [ -n "$THEME" ]; then
    require_theme_assets "$THEME"
    return 0
  fi

  if [ "$ASSUME_YES" -eq 1 ] || [ ! -t 0 ]; then
    THEME="night-owl"
    require_theme_assets "$THEME"
    return 0
  fi

  log "Select a theme:"
  choices="$(find "$THEMES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)"
  idx=1
  default_idx=1
  for name in $choices; do
    if [ "$name" = "night-owl" ]; then
      default_idx="$idx"
    fi
    log "$idx) $name"
    idx=$((idx + 1))
  done

  printf "Choice [1-%s] (default %s): " "$((idx - 1))" "$default_idx"
  IFS= read -r input
  input="${input:-$default_idx}"

  if [ -z "$input" ]; then
    input="$default_idx"
  fi

  if [ "$input" -ge 1 ] 2>/dev/null && [ "$input" -lt "$idx" ] 2>/dev/null; then
    sel=1
    for name in $choices; do
      if [ "$sel" -eq "$input" ]; then
        THEME="$name"
        break
      fi
      sel=$((sel + 1))
    done
  else
    THEME="$input"
  fi

  require_theme_assets "$THEME"
}

link_path() {
  src="$1"
  dst="$2"

  if [ ! -e "$src" ]; then
    log "skip (missing source): $src"
    return 0
  fi

  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ] || [ -e "$dst" ]; then
    rm -rf "$dst"
  fi
  ln -s "$src" "$dst"
  log "linked: $dst -> $src"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --theme)
      shift
      [ "$#" -gt 0 ] || { log "error: --theme requires a value"; exit 1; }
      THEME="$1"
      ;;
    --yes)
      ASSUME_YES=1
      ;;
    --theme-only)
      THEME_ONLY=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log "error: unknown argument: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

choose_theme
log "Bootstrapping dotfiles (theme: $THEME)"

if is_light_theme "$THEME"; then
  update_claude_theme "light-ansi"
else
  update_claude_theme "dark-ansi"
fi

if [ "$THEME_ONLY" -eq 0 ]; then
  # Core dotfiles
  link_path "$DOTFILES_DIR/.zshrc" "$HOME_DIR/.zshrc"
  link_path "$DOTFILES_DIR/.zprofile" "$HOME_DIR/.zprofile"
  link_path "$DOTFILES_DIR/.zshenv" "$HOME_DIR/.zshenv"
  link_path "$DOTFILES_DIR/.p10k.zsh" "$HOME_DIR/.p10k.zsh"
  link_path "$DOTFILES_DIR/.config/alacritty" "$HOME_DIR/.config/alacritty"
  link_path "$DOTFILES_DIR/.config/nvim" "$HOME_DIR/.config/nvim"
  link_path "$DOTFILES_DIR/.tmux.conf" "$HOME_DIR/.tmux.conf"

  # Optional XMonad config
  if [ -e "$DOTFILES_DIR/.xmonad/xmonad.hs" ]; then
    link_path "$DOTFILES_DIR/.xmonad/xmonad.hs" "$HOME_DIR/.xmonad/xmonad.hs"
  fi

  # CLI config links
  mkdir -p "$HOME_DIR/.codex"
  link_path "$DOTFILES_DIR/codex/config.toml" "$HOME_DIR/.codex/config.toml"
  link_path "$DOTFILES_DIR/claude/config.json" "$HOME_DIR/.claude.json"
fi

# Theme links
link_path "$DOTFILES_DIR/themes/$THEME/alacritty.toml" "$HOME_DIR/.config/alacritty/theme.toml"
log "updated: $HOME_DIR/.config/alacritty/theme.toml (theme: $THEME)"
touch "$HOME_DIR/.config/alacritty/alacritty.toml"
if [ -f "$HOME_DIR/.config/alacritty/alacritty.toml" ] \
  && ! grep -q 'theme.toml' "$HOME_DIR/.config/alacritty/alacritty.toml"; then
  log "warn: $HOME_DIR/.config/alacritty/alacritty.toml does not import theme.toml"
fi
link_path "$DOTFILES_DIR/themes/$THEME/tmux.conf" "$HOME_DIR/.tmux-theme.conf"
link_path "$DOTFILES_DIR/themes/$THEME/nvim-theme.lua" "$HOME_DIR/.config/nvim/lua/paarth/theme.lua"

# Write COLORFGBG so TUI apps (codex etc.) detect dark/light correctly
if is_light_theme "$THEME"; then
  printf 'export COLORFGBG="0;15"\n' > "$HOME_DIR/.theme-env"
else
  printf 'export COLORFGBG="15;0"\n' > "$HOME_DIR/.theme-env"
fi
log "updated: $HOME_DIR/.theme-env (COLORFGBG for $THEME)"

log "Bootstrap complete."
if tmux info >/dev/null 2>&1; then
  tmux source-file ~/.tmux.conf \; refresh-client -S
  log "tmux config reloaded."
fi

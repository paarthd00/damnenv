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

if [ "$THEME_ONLY" -eq 0 ]; then
  # Core dotfiles
  link_path "$DOTFILES_DIR/.zshrc" "$HOME_DIR/.zshrc"
  link_path "$DOTFILES_DIR/.zprofile" "$HOME_DIR/.zprofile"
  link_path "$DOTFILES_DIR/.zshenv" "$HOME_DIR/.zshenv"
  link_path "$DOTFILES_DIR/.p10k.zsh" "$HOME_DIR/.p10k.zsh"
  link_path "$DOTFILES_DIR/.config/alacritty" "$HOME_DIR/.config/alacritty"
  link_path "$DOTFILES_DIR/.config/nvim" "$HOME_DIR/.config/nvim"

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
link_path "$DOTFILES_DIR/themes/$THEME/alacritty.toml" "$HOME_DIR/.config/alacritty/alacritty.toml"
link_path "$DOTFILES_DIR/themes/$THEME/tmux.conf" "$HOME_DIR/.tmux.conf"
link_path "$DOTFILES_DIR/themes/$THEME/nvim-theme.lua" "$HOME_DIR/.config/nvim/lua/paarth/theme.lua"

log "Bootstrap complete."
log "If tmux is running, reload with: tmux source-file ~/.tmux.conf \\; refresh-client -S"

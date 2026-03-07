#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)"
PWD_DIR="$(pwd -P)"
DOTFILES_DIR="${DOTFILES_DIR:-$SCRIPT_DIR}"
# If the script is invoked from a copied location, allow falling back to CWD.
if [ ! -d "$DOTFILES_DIR/themes" ] && [ -d "$PWD_DIR/themes" ] && [ -f "$PWD_DIR/bootstrap.sh" ]; then
  DOTFILES_DIR="$PWD_DIR"
fi
HOME_DIR="${HOME:?HOME is required}"
THEMES_DIR="$DOTFILES_DIR/themes"
OMZ_DIR="$HOME_DIR/.oh-my-zsh"
ZSH_CUSTOM="${ZSH_CUSTOM:-$OMZ_DIR/custom}"

THEME="${THEME:-}"
ASSUME_YES=0
THEME_ONLY=0

# ── Helpers ───────────────────────────────────────────────────────────

log() { printf '%s\n' "$*"; }

usage() {
  cat <<EOF
Usage: ./bootstrap.sh [options]

  --theme THEME    Apply a specific theme directly
  --yes            Non-interactive (default theme: night-owl)
  --theme-only     Only re-apply theme symlinks; skip core dotfile links
  -h, --help
EOF
}

has_cmd()   { command -v "$1" >/dev/null 2>&1; }
has_sway()  { has_cmd sway || [ -d "$HOME_DIR/.config/sway" ]; }
has_xmonad(){ has_cmd xmonad || [ -f "$HOME_DIR/.xmonad/xmonad.hs" ]; }
has_omz()   { [ -d "$OMZ_DIR" ]; }
has_omz_plugin() { [ -d "$ZSH_CUSTOM/plugins/$1" ]; }

wm_is_running() { pgrep -x "$1" >/dev/null 2>&1; }
is_light_theme() { case "$1" in *light*) return 0 ;; *) return 1 ;; esac; }

link_path() {
  src="$1"
  dst="$2"
  dst_dir="$(dirname "$dst")"
  rel_src=""

  [ -e "$src" ] || { log "  skip (missing): $src"; return 0; }

  # Already linked correctly — skip
  [ "$src" -ef "$dst" ] && { log "  ok: $dst"; return 0; }

  mkdir -p "$dst_dir"
  [ -L "$dst" ] || [ -e "$dst" ] && rm -f "$dst"

  # Relative symlink — survives dotfiles dir being moved
  rel_src="$(realpath --relative-to="$dst_dir" "$src")"
  ln -s "$rel_src" "$dst"
  log "  linked: $dst -> $rel_src"
}

# ── Dependency check ──────────────────────────────────────────────────

check_deps() {
  log "── Checking dependencies ───────────────────────────────────────"

  for cmd in git curl; do
    if ! has_cmd "$cmd"; then
      log "  ERROR: '$cmd' is required but not installed. Install it and re-run."
      exit 1
    fi
  done

  has_cmd rg    || log "  warn: 'ripgrep' not found — needed for Neovim live grep. https://github.com/BurntSushi/ripgrep#installation"
  has_cmd nvim  || log "  warn: 'nvim' not found. https://neovim.io"
  has_cmd zsh   || log "  info: 'zsh' not found — zsh dotfiles will be skipped."
  has_cmd tmux  || log "  info: 'tmux' not found — tmux dotfiles will be skipped."

  if has_cmd alacritty || has_cmd ghostty; then
    term=""
    has_cmd alacritty && term="alacritty"
    has_cmd ghostty   && term="${term:+$term, }ghostty"
    log "  ok: terminal ($term)"
  else
    log "  warn: Neither 'alacritty' nor 'ghostty' found. https://alacritty.org | https://ghostty.org"
  fi

  if has_sway || has_xmonad; then
    wm=""
    has_sway   && wm="sway"
    has_xmonad && wm="${wm:+$wm, }xmonad"
    log "  ok: window manager ($wm)"
  else
    log "  warn: Neither Sway nor XMonad detected. https://swaywm.org | https://xmonad.org"
  fi

  log "────────────────────────────────────────────────────────────────"
  log ""
}

# ── Theme ─────────────────────────────────────────────────────────────

require_theme_assets() {
  chosen="$1"
  for rel in alacritty.toml tmux.conf nvim-theme.lua sway-colors.conf waybar-colors.css wofi-colors.css xmobarrc xmonad-colors.hs; do
    [ -f "$THEMES_DIR/$chosen/$rel" ] || {
      log "error: missing theme asset: $THEMES_DIR/$chosen/$rel"
      exit 1
    }
  done
}

choose_theme() {
  if [ -n "$THEME" ]; then require_theme_assets "$THEME"; return 0; fi
  if [ "$ASSUME_YES" -eq 1 ] || [ ! -t 0 ]; then
    THEME="night-owl"; require_theme_assets "$THEME"; return 0
  fi

  log "Select a theme:"
  choices="$(find "$THEMES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)"
  idx=1; default_idx=1
  for name in $choices; do
    [ "$name" = "night-owl" ] && default_idx="$idx"
    log "  $idx) $name"
    idx=$((idx + 1))
  done
  printf "Choice [1-%s] (default %s): " "$((idx - 1))" "$default_idx"
  IFS= read -r input; input="${input:-$default_idx}"

  if [ "$input" -ge 1 ] 2>/dev/null && [ "$input" -lt "$idx" ] 2>/dev/null; then
    sel=1
    for name in $choices; do
      [ "$sel" -eq "$input" ] && { THEME="$name"; break; }
      sel=$((sel + 1))
    done
  else
    THEME="$input"
  fi
  require_theme_assets "$THEME"
}

update_claude_theme() {
  config_file="$DOTFILES_DIR/claude/config.json"
  desired_theme="$1"
  [ ! -f "$config_file" ] && { log "  skip (missing): $config_file"; return 0; }
  tmp_file="$(mktemp)"
  if awk -v theme="$desired_theme" '
    BEGIN { saw_theme = 0; inserted = 0 }
    {
      if ($0 ~ /^  "theme"[[:space:]]*:[[:space:]]*"/) {
        if (!saw_theme) { print "  \"theme\": \"" theme "\","; saw_theme = 1 }
        next
      }
      if (!saw_theme && !inserted && $0 ~ /^[[:space:]]*{[[:space:]]*$/) {
        print; print "  \"theme\": \"" theme "\","; inserted = 1; saw_theme = 1; next
      }
      print
    }
    END { if (!saw_theme) { exit 1 } }
  ' "$config_file" >"$tmp_file"; then
    mv "$tmp_file" "$config_file"
    log "  updated: claude config (theme = $desired_theme)"
  else
    rm -f "$tmp_file"
    log "  warn: could not update theme in $config_file"
  fi
}

# ── Arg parsing ───────────────────────────────────────────────────────

while [ "$#" -gt 0 ]; do
  case "$1" in
    --theme)      shift; [ "$#" -gt 0 ] || { log "error: --theme requires a value"; exit 1; }; THEME="$1" ;;
    --yes)        ASSUME_YES=1 ;;
    --theme-only) THEME_ONLY=1 ;;
    -h|--help)    usage; exit 0 ;;
    *)            log "error: unknown argument: $1"; usage; exit 1 ;;
  esac
  shift
done

# ── Main ──────────────────────────────────────────────────────────────

check_deps
choose_theme
log "Bootstrapping dotfiles (theme: $THEME)"
log ""

if is_light_theme "$THEME"; then
  update_claude_theme "light-ansi"
else
  update_claude_theme "dark-ansi"
fi

if [ "$THEME_ONLY" -eq 0 ]; then
  log "── Linking dotfiles ────────────────────────────────────────────"

  # Zsh — only if installed
  if has_cmd zsh; then
    link_path "$DOTFILES_DIR/home/profile/zsh_rc.zsh"      "$HOME_DIR/.zshrc"
    link_path "$DOTFILES_DIR/home/profile/zsh_profile.zsh" "$HOME_DIR/.zprofile"
    link_path "$DOTFILES_DIR/home/profile/zsh_env.zsh"     "$HOME_DIR/.zshenv"
    link_path "$DOTFILES_DIR/home/profile/zsh_p10k.zsh"    "$HOME_DIR/.p10k.zsh"
  else
    log "  skip: zsh dotfiles (zsh not installed)"
  fi

  # Alacritty — only if installed
  if has_cmd alacritty; then
    link_path "$DOTFILES_DIR/home/config/alacritty" "$HOME_DIR/.config/alacritty"
  else
    log "  skip: alacritty config (not installed)"
  fi

  link_path "$DOTFILES_DIR/home/config/nvim" "$HOME_DIR/.config/nvim"

  # Sway — only if detected
  if has_sway; then
    link_path "$DOTFILES_DIR/home/config/wofi"      "$HOME_DIR/.config/wofi"
    link_path "$DOTFILES_DIR/managers/sway"         "$HOME_DIR/.config/sway"
    link_path "$DOTFILES_DIR/managers/sway/waybar"  "$HOME_DIR/.config/waybar"
  else
    log "  skip: sway/waybar/wofi configs (sway not detected)"
  fi

  # Tmux — only if installed
  if has_cmd tmux; then
    link_path "$DOTFILES_DIR/home/profile/zsh_tmux_conf.zsh" "$HOME_DIR/.tmux.conf"
  else
    log "  skip: tmux config (not installed)"
  fi

  # XMonad config — only if detected
  if has_xmonad && [ -e "$DOTFILES_DIR/managers/xmonad/xmonad.hs" ]; then
    link_path "$DOTFILES_DIR/managers/xmonad/xmonad.hs" "$HOME_DIR/.xmonad/xmonad.hs"
  fi

  # CLI tool configs
  mkdir -p "$HOME_DIR/.codex"
  link_path "$DOTFILES_DIR/codex/config.toml" "$HOME_DIR/.codex/config.toml"
  link_path "$DOTFILES_DIR/claude/config.json" "$HOME_DIR/.claude.json"

  log "────────────────────────────────────────────────────────────────"
  log ""
fi

# ── Theme links ───────────────────────────────────────────────────────
log "── Applying theme: $THEME ──────────────────────────────────────"

# Alacritty theme
if has_cmd alacritty; then
  link_path "$DOTFILES_DIR/themes/$THEME/alacritty.toml" "$HOME_DIR/.config/alacritty/theme.toml"
  mkdir -p "$HOME_DIR/.config/alacritty"
  if [ ! -f "$HOME_DIR/.config/alacritty/alacritty.toml" ]; then
    printf 'import = ["~/.config/alacritty/theme.toml"]\n' > "$HOME_DIR/.config/alacritty/alacritty.toml"
    log "  created: alacritty.toml with theme import"
  elif ! grep -q 'theme.toml' "$HOME_DIR/.config/alacritty/alacritty.toml"; then
    log "  warn: alacritty.toml does not import theme.toml"
  fi
else
  log "  skip: alacritty theme (not installed)"
fi

# Neovim theme (always — nvim config linked regardless of nvim presence)
link_path "$DOTFILES_DIR/themes/$THEME/nvim-theme.lua" "$HOME_DIR/.config/nvim/lua/paarth/theme.lua"

# Tmux theme
if has_cmd tmux; then
  link_path "$DOTFILES_DIR/themes/$THEME/tmux.conf" "$HOME_DIR/.tmux-theme.conf"
else
  log "  skip: tmux theme (not installed)"
fi

# Sway theme
if has_sway; then
  link_path "$DOTFILES_DIR/themes/$THEME/sway-colors.conf" "$HOME_DIR/.config/sway/colors.conf"
  mkdir -p "$HOME_DIR/.config/waybar" "$HOME_DIR/.config/wofi"
  cat "$DOTFILES_DIR/themes/$THEME/waybar-colors.css" "$DOTFILES_DIR/managers/sway/waybar/style-base.css" \
    > "$HOME_DIR/.config/waybar/style.css"
  log "  generated: waybar style.css"
  cat "$DOTFILES_DIR/themes/$THEME/wofi-colors.css" "$DOTFILES_DIR/home/config/wofi/style-base.css" \
    > "$HOME_DIR/.config/wofi/style.css"
  log "  generated: wofi style.css"
  if wm_is_running sway && swaymsg reload >/dev/null 2>&1; then
    log "  sway config reloaded"
  fi
else
  log "  skip: sway theme (sway not detected)"
fi

# XMonad theme
if has_xmonad; then
  link_path "$DOTFILES_DIR/themes/$THEME/xmobarrc" "$HOME_DIR/xmobarrc"
  mkdir -p "$HOME_DIR/.xmonad/lib"
  link_path "$DOTFILES_DIR/themes/$THEME/xmonad-colors.hs" "$HOME_DIR/.xmonad/lib/Colors.hs"
  log "  updated: xmonad theme (xmobarrc + Colors.hs)"
  if wm_is_running xmonad; then
    if xmonad --recompile 2>/dev/null; then
      xmonad --restart
      log "  xmonad recompiled and restarted"
    else
      log "  warn: xmonad --recompile failed; run manually to see errors"
    fi
  fi
else
  log "  skip: xmonad theme (xmonad not detected)"
fi

# COLORFGBG for TUI apps
if is_light_theme "$THEME"; then
  printf 'export COLORFGBG="0;15"\n' > "$HOME_DIR/.theme-env"
else
  printf 'export COLORFGBG="15;0"\n' > "$HOME_DIR/.theme-env"
fi
log "  updated: ~/.theme-env"

log "────────────────────────────────────────────────────────────────"
log ""
log "Bootstrap complete."

if has_cmd tmux && tmux info >/dev/null 2>&1; then
  tmux source-file ~/.tmux.conf \; refresh-client -S
  log "tmux config reloaded."
fi

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
has_alacritty() { has_cmd alacritty || [ -d "/Applications/Alacritty.app" ] || [ -d "$HOME_DIR/Applications/Alacritty.app" ]; }
has_ghostty() { has_cmd ghostty || [ -d "/Applications/Ghostty.app" ] || [ -d "$HOME_DIR/Applications/Ghostty.app" ]; }
is_macos() { [ "$(uname -s)" = "Darwin" ]; }
has_brew() { command -v brew >/dev/null 2>&1; }
has_fira_code() {
  if is_macos; then
    for dir in "$HOME_DIR/Library/Fonts" "/Library/Fonts" "/System/Library/Fonts"; do
      [ -d "$dir" ] || continue
      find "$dir" -maxdepth 1 \( -iname '*Fira*Code*' -o -iname 'FiraCode*' \) -print -quit 2>/dev/null | grep -q .
      if [ "$?" -eq 0 ]; then
        return 0
      fi
    done
    return 1
  fi

  if has_cmd fc-list; then
    fc-list | grep -iq 'Fira Code'
    return "$?"
  fi

  return 1
}

print_install_hint() {
  pkg="$1"
  cask="${2:-0}"

  if is_macos; then
    if has_brew; then
      if [ "$cask" -eq 1 ]; then
        log "  hint: install with 'brew install --cask $pkg'"
      else
        log "  hint: install with 'brew install $pkg'"
      fi
    else
      log "  hint: Homebrew not found. Install it from https://brew.sh and then run:"
      if [ "$cask" -eq 1 ]; then
        log "        brew install --cask $pkg"
      else
        log "        brew install $pkg"
      fi
    fi
    return 0
  fi

  if has_cmd apt-get; then
    log "  hint: install with 'sudo apt-get install -y $pkg'"
  elif has_cmd dnf; then
    log "  hint: install with 'sudo dnf install -y $pkg'"
  elif has_cmd pacman; then
    log "  hint: install with 'sudo pacman -S --needed $pkg'"
  elif has_cmd zypper; then
    log "  hint: install with 'sudo zypper install -y $pkg'"
  fi
}

wm_is_running() { pgrep -x "$1" >/dev/null 2>&1; }
is_light_theme() { case "$1" in *light*) return 0 ;; *) return 1 ;; esac; }

# Push OSC color sequences to all user-owned pts devices for live theme update.
# Works in any running terminal that supports OSC 4/10/11/12 (ghostty, alacritty, etc.)
push_osc_colors() {
  theme_file="$1"
  [ -f "$theme_file" ] || return 0
  sequences="$(awk '
    /^background = /   { printf "\033]11;%s\007", $3 }
    /^foreground = /   { printf "\033]10;%s\007", $3 }
    /^cursor-color = / { printf "\033]12;%s\007", $3 }
    /^palette = /      { split($3, a, "="); printf "\033]4;%s;%s\007", a[1], a[2] }
  ' "$theme_file")"
  for pts in /dev/pts/*; do
    [ -c "$pts" ] && [ -w "$pts" ] || continue
    printf '%s' "$sequences" > "$pts" 2>/dev/null || true
  done
}

link_path() {
  src="$1"
  dst="$2"
  dst_dir="$(dirname "$dst")"
  dst_dir_real=""
  rel_src=""

  [ -e "$src" ] || { log "  skip (missing): $src"; return 0; }

  # Already linked correctly — skip
  [ "$src" -ef "$dst" ] && { log "  ok: $dst"; return 0; }

  mkdir -p "$dst_dir"
  dst_dir_real="$(CDPATH= cd -- "$dst_dir" && pwd -P)"
  [ -L "$dst" ] || [ -e "$dst" ] && rm -f "$dst"

  # Relative symlink — survives dotfiles dir being moved
  if realpath --relative-to="$dst_dir_real" "$src" >/dev/null 2>&1; then
    rel_src="$(realpath --relative-to="$dst_dir_real" "$src")"
  else
    rel_src="$(LC_ALL=C perl -e 'use File::Spec; print File::Spec->abs2rel($ARGV[0], $ARGV[1])' "$src" "$dst_dir_real")"
  fi
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

  if ! has_cmd rg; then
    log "  warn: 'ripgrep' not found — needed for Neovim live grep. https://github.com/BurntSushi/ripgrep#installation"
    print_install_hint ripgrep
  fi
  if ! has_cmd nvim; then
    log "  warn: 'nvim' not found. https://neovim.io"
    print_install_hint neovim
  fi
  if ! has_fira_code; then
    log "  warn: 'Fira Code' font not found. Alacritty config expects it."
    if is_macos; then
      if has_brew; then
        log "  hint: install with 'brew install --cask font-fira-code'"
      else
        log "  hint: install Homebrew from https://brew.sh and then run:"
        log "        brew install --cask font-fira-code"
      fi
    elif has_cmd fc-list; then
      log "  hint: install the Fira Code font package for your distro"
    fi
  fi
  has_cmd zsh   || log "  info: 'zsh' not found — zsh dotfiles will be skipped."
  has_cmd tmux  || log "  info: 'tmux' not found — tmux dotfiles will be skipped."
  if ! has_cmd tmux; then
    print_install_hint tmux
  fi

  if has_alacritty || has_ghostty; then
    term=""
    has_alacritty && term="alacritty"
    has_ghostty   && term="${term:+$term, }ghostty"
    log "  ok: terminal ($term)"
  else
    log "  warn: Neither 'alacritty' nor 'ghostty' found. https://alacritty.org | https://ghostty.org"
    print_install_hint alacritty 1
  fi

  if has_sway || has_xmonad; then
    wm=""
    has_sway   && wm="sway"
    has_xmonad && wm="${wm:+$wm, }xmonad"
    log "  ok: window manager theme($wm)"
  else
    log "  warn: Neither Sway nor XMonad detected. https://swaywm.org | https://xmonad.org"
  fi

  log "────────────────────────────────────────────────────────────────"
  log ""
}

# ── Optional installs ────────────────────────────────────────────────

ensure_p10k() {
  [ -d "$OMZ_DIR" ] || return 0
  [ -d "$ZSH_CUSTOM" ] || return 0
  [ -d "$ZSH_CUSTOM/themes/powerlevel10k" ] && return 0
  if has_cmd git; then
    log "  installing: powerlevel10k (oh-my-zsh theme)"
    git clone --depth=1 https://github.com/romkatv/powerlevel10k "$ZSH_CUSTOM/themes/powerlevel10k" >/dev/null 2>&1 \
      && log "  ok: powerlevel10k installed" \
      || log "  warn: failed to install powerlevel10k"
  fi
}

ensure_alacritty_dir() {
  mkdir -p "$HOME_DIR/.config"
  if [ -L "$HOME_DIR/.config/alacritty" ] && is_macos; then
    rm -f "$HOME_DIR/.config/alacritty"
  fi
  mkdir -p "$HOME_DIR/.config/alacritty"
}

# ── Theme ─────────────────────────────────────────────────────────────

require_theme_assets() {
  chosen="$1"
  for rel in alacritty.toml tmux.conf nvim-theme.lua sway-colors.conf waybar-colors.css wofi-colors.css xmobarrc xmonad-colors.hs ghostty.conf; do
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
  choices=""
  for d in "$THEMES_DIR"/*; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    choices="${choices}
${name}"
  done
  choices="$(printf '%s\n' "$choices" | sed '/^$/d' | sort)"
  if [ -z "$choices" ]; then
    log "error: no themes found in $THEMES_DIR"
    exit 1
  fi
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
    ensure_p10k
    link_path "$DOTFILES_DIR/home/profile/zsh_rc.zsh"      "$HOME_DIR/.zshrc"
    link_path "$DOTFILES_DIR/home/profile/zsh_profile.zsh" "$HOME_DIR/.zprofile"
    link_path "$DOTFILES_DIR/home/profile/zsh_env.zsh"     "$HOME_DIR/.zshenv"
    link_path "$DOTFILES_DIR/home/profile/zsh_p10k.zsh"    "$HOME_DIR/.p10k.zsh"
  else
    log "  skip: zsh dotfiles (zsh not installed)"
  fi

  # Alacritty — only if installed
  if has_alacritty; then
    if is_macos; then
      ensure_alacritty_dir
      link_path "$DOTFILES_DIR/home/config/alacritty/alacritty.toml" "$HOME_DIR/.config/alacritty/alacritty.toml"
    else
      mkdir -p "$HOME_DIR/.config"
      link_path "$DOTFILES_DIR/home/config/alacritty" "$HOME_DIR/.config/alacritty"
    fi
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
if has_alacritty; then
  ensure_alacritty_dir
  [ -L "$HOME_DIR/.config/alacritty/theme.toml" ] && rm -f "$HOME_DIR/.config/alacritty/theme.toml"
  if is_macos; then
    # On macOS, prefer a real file to ensure FSEvents reloads immediately
    cp "$DOTFILES_DIR/themes/$THEME/alacritty.toml" "$HOME_DIR/.config/alacritty/theme.toml"
    log "  copied: alacritty theme (macOS refresh)"
  else
    link_path "$DOTFILES_DIR/themes/$THEME/alacritty.toml" "$HOME_DIR/.config/alacritty/theme.toml"
  fi
  if [ ! -f "$HOME_DIR/.config/alacritty/alacritty.toml" ]; then
    printf 'import = ["~/.config/alacritty/theme.toml"]\n' > "$HOME_DIR/.config/alacritty/alacritty.toml"
    log "  created: alacritty.toml with theme import"
  elif ! grep -q 'theme.toml' "$HOME_DIR/.config/alacritty/alacritty.toml"; then
    printf '\n# Theme (set by bootstrap.sh)\nimport = ["~/.config/alacritty/theme.toml"]\n' >> "$HOME_DIR/.config/alacritty/alacritty.toml"
    log "  patched: alacritty.toml (added theme import)"
  else
    # Touch the main config to trigger alacritty's inotify watcher (symlink re-targeting doesn't fire it)
    touch "$HOME_DIR/.config/alacritty/alacritty.toml"
    log "  alacritty config touched (live reload triggered)"
  fi
  # Ensure the theme file mtime changes so Alacritty reloads immediately on macOS
  touch "$HOME_DIR/.config/alacritty/theme.toml"
else
  log "  skip: alacritty theme (not installed)"
fi

# Ghostty theme
if has_ghostty; then
  mkdir -p "$HOME_DIR/.config/ghostty"
  link_path "$DOTFILES_DIR/themes/$THEME/ghostty.conf" "$HOME_DIR/.config/ghostty/theme"
  ghostty_cfg="$HOME_DIR/.config/ghostty/config"
  if [ ! -f "$ghostty_cfg" ]; then
    cp "$DOTFILES_DIR/home/config/ghostty/config" "$ghostty_cfg"
    log "  created: ghostty config"
  elif ! grep -q 'config-file.*theme' "$ghostty_cfg"; then
    printf '\n# Theme (set by bootstrap.sh)\nconfig-file = ~/.config/ghostty/theme\n' >> "$ghostty_cfg"
    log "  patched: ghostty config (added config-file directive)"
  fi
  touch "$ghostty_cfg"
  push_osc_colors "$DOTFILES_DIR/themes/$THEME/ghostty.conf"
  log "  ghostty theme applied (existing windows updated via OSC sequences)"
else
  log "  skip: ghostty theme (not installed)"
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

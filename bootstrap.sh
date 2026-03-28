#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
DOTFILES_DIR="${DOTFILES_DIR:-$SCRIPT_DIR}"
THEMES_DIR="$DOTFILES_DIR/themes"

THEME="${THEME:-}"
ASSUME_YES=0
BACKUP_EXT="${RANG_BACKUP_EXT:-rang-backup}"
NIX_EXPERIMENTAL_FEATURES="nix-command flakes"
REMOVE_FEDORA_OVERLAP=0

log() { printf '%s\n' "$*"; }
has_cmd() { command -v "$1" >/dev/null 2>&1; }
wm_is_running() { pgrep -x "$1" >/dev/null 2>&1; }

restore_repo_file_from_backup() {
  path="$1"
  backup="$path.$BACKUP_EXT"

  [ -L "$path" ] || return 0
  [ -f "$backup" ] || return 0

  target="$(readlink "$path" 2>/dev/null || true)"
  case "$target" in
    /nix/store/*)
      log "  restoring repo source: $path"
      rm -f "$path"
      mv "$backup" "$path"
      ;;
  esac
}

repair_repo_sources() {
  log "Checking for repo source files replaced by Home Manager"

  for dir in \
    "$DOTFILES_DIR/home/config" \
    "$DOTFILES_DIR/window-managers"
  do
    [ -d "$dir" ] || continue

    find "$dir" -type f -name "*.$BACKUP_EXT" | while IFS= read -r backup; do
      path=${backup%."$BACKUP_EXT"}
      restore_repo_file_from_backup "$path"
    done
  done
}

remove_legacy_child_links() {
  dir="$1"
  [ -d "$dir" ] || return 0

  find "$dir" -mindepth 1 -xtype l 2>/dev/null | while IFS= read -r child; do
    if is_repo_managed_symlink "$child"; then
      log "  removing legacy nested link: $child -> $(readlink "$child")"
      rm -f "$child"
    fi
  done
}

download_file() {
  url="$1"
  dest="$2"

  if has_cmd curl; then
    curl --proto '=https' --tlsv1.2 -fsSL -o "$dest" "$url"
    return 0
  fi

  if has_cmd wget; then
    wget -qO "$dest" "$url"
    return 0
  fi

  return 1
}

load_nix_env() {
  has_cmd nix && return 0

  for script in \
    "$HOME/.nix-profile/etc/profile.d/nix.sh" \
    "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" \
    "/nix/var/nix/profiles/default/etc/profile.d/nix.sh"
  do
    [ -r "$script" ] || continue
    # shellcheck disable=SC1090
    . "$script"
    has_cmd nix && return 0
  done

  return 1
}

run_nix() {
  ensure_nix_features
  nix --extra-experimental-features "$NIX_EXPERIMENTAL_FEATURES" "$@"
}

ensure_nix_features() {
  case "${NIX_CONFIG-}" in
    *nix-command*flakes*|*flakes*nix-command*) return 0 ;;
  esac

  if [ -n "${NIX_CONFIG-}" ]; then
    export NIX_CONFIG="${NIX_CONFIG}
experimental-features = ${NIX_EXPERIMENTAL_FEATURES}"
  else
    export NIX_CONFIG="experimental-features = ${NIX_EXPERIMENTAL_FEATURES}"
  fi
}

install_nix() {
  load_nix_env && return 0

  case "$(uname -s)" in
    Linux) ;;
    *)
      log "error: automatic Nix installation is only supported here on Linux"
      exit 1
      ;;
  esac

  if [ "$ASSUME_YES" -ne 1 ] && [ -t 0 ]; then
    printf "Nix is not installed. Install the official single-user Nix now? [Y/n]: "
    IFS= read -r reply
    case "$reply" in
      ""|y|Y|yes|YES) ;;
      *)
        log "error: nix is required to apply rang"
        log "       install it with: sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --no-daemon"
        exit 1
        ;;
    esac
  fi

  installer="$(mktemp "${TMPDIR:-/tmp}/rang-nix-install.XXXXXX")"
  if ! download_file "https://nixos.org/nix/install" "$installer"; then
    rm -f "$installer"
    log "error: could not download the Nix installer (need curl or wget)"
    exit 1
  fi

  log "Installing Nix (single-user)..."
  if ! sh "$installer" --no-daemon; then
    rm -f "$installer"
    log "error: Nix installation failed"
    exit 1
  fi
  rm -f "$installer"

  if ! load_nix_env; then
    log "error: Nix installed, but this shell could not load it"
    log "       open a new shell and rerun ./bootstrap.sh"
    exit 1
  fi
}

is_repo_managed_symlink() {
  path="$1"
  [ -L "$path" ] || return 1

  link="$(readlink "$path" 2>/dev/null || true)"
  case "$link" in
    "$DOTFILES_DIR"/*|../WM-Theme/*|../rang/*|*/WM-Theme/*|*/rang/*) return 0 ;;
  esac

  if has_cmd realpath; then
    resolved="$(realpath -m "$path" 2>/dev/null || true)"
    case "$resolved" in
      "$DOTFILES_DIR"/*) return 0 ;;
    esac
  fi

  return 1
}

usage() {
  cat <<EOF
Usage: ./bootstrap.sh [options]

Applies the rang Home Manager setup and selects a theme.

  --theme THEME    Apply a specific theme directly
  --yes            Non-interactive (default theme: night-owl)
  --theme THEME             Apply a specific theme directly
  --yes                     Non-interactive (default theme: night-owl)
  --remove-fedora-overlap   Remove overlapping Fedora RPM packages after a successful apply
  -h, --help
EOF
}

require_theme_assets() {
  chosen="$1"
  for rel in alacritty.toml ghostty.conf nvim-theme.lua sway-colors.conf tmux.conf waybar-colors.css wofi-colors.css xmobarrc xmonad-colors.hs; do
    [ -f "$THEMES_DIR/$chosen/$rel" ] || {
      log "error: missing theme asset: $THEMES_DIR/$chosen/$rel"
      exit 1
    }
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

  log "Select a rang theme:"
  choices=""
  for d in "$THEMES_DIR"/*; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    choices="${choices}
${name}"
  done
  choices="$(printf '%s\n' "$choices" | sed '/^$/d' | sort)"
  [ -n "$choices" ] || {
    log "error: no themes found in $THEMES_DIR"
    exit 1
  }

  idx=1
  default_idx=1
  for name in $choices; do
    [ "$name" = "night-owl" ] && default_idx="$idx"
    log "  $idx) $name"
    idx=$((idx + 1))
  done
  printf "Choice [1-%s] (default %s): " "$((idx - 1))" "$default_idx"
  IFS= read -r input
  input="${input:-$default_idx}"

  if [ "$input" -ge 1 ] 2>/dev/null && [ "$input" -lt "$idx" ] 2>/dev/null; then
    sel=1
    for name in $choices; do
      [ "$sel" -eq "$input" ] && {
        THEME="$name"
        break
      }
      sel=$((sel + 1))
    done
  else
    THEME="$input"
  fi

  require_theme_assets "$THEME"
}

migrate_legacy_links() {
  log "Checking for legacy repo-managed config links"

  for path in \
    "$HOME/.config/alacritty" \
    "$HOME/.config/nvim" \
    "$HOME/.config/sway" \
    "$HOME/.config/waybar" \
    "$HOME/.config/wofi"
  do
    if is_repo_managed_symlink "$path"; then
      log "  removing legacy link: $path -> $(readlink "$path")"
      rm -f "$path"
    fi
  done
}

find_fedora_binary() {
  cmd="$1"
  search_path="/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
  old_ifs=$IFS
  IFS=:
  for dir in $search_path; do
    case "$dir" in
      /nix/*|"$HOME"/.nix-profile/*) continue ;;
      /usr/bin|/usr/sbin|/bin|/sbin|*/usr/bin|*/usr/sbin|*/bin|*/sbin) ;;
      *) continue ;;
    esac

    candidate="$dir/$cmd"
    if [ -x "$candidate" ] && [ ! -d "$candidate" ]; then
      printf '%s\n' "$candidate"
      IFS=$old_ifs
      return 0
    fi
  done
  IFS=$old_ifs
  return 1
}

fedora_overlap_packages() {
  has_cmd rpm || return 0
  has_cmd dnf || return 0

  packages=""
  for cmd in \
    git curl nvim rg tmux fzf fd fdfind bat eza \
    alacritty ghostty firefox sway waybar wofi mako swayidle swaylock \
    pavucontrol brightnessctl wl-copy xdg-open xmonad xmobar \
    codex claude opencode zed zeditor
  do
    path="$(find_fedora_binary "$cmd" 2>/dev/null || true)"
    [ -n "$path" ] || continue
    pkg="$(rpm -qf --qf '%{NAME}\n' "$path" 2>/dev/null || true)"
    [ -n "$pkg" ] || continue

    # Keep the distro login shell until the account shell points at the Nix one.
    [ "$pkg" = "zsh" ] && continue

    packages="${packages}
${pkg}"
  done

  printf '%s\n' "$packages" | sed '/^$/d' | sort -u
}

remove_fedora_overlap() {
  [ "$REMOVE_FEDORA_OVERLAP" -eq 1 ] || return 0

  if ! has_cmd rpm || ! has_cmd dnf; then
    log "Skipping Fedora overlap removal: rpm/dnf not available"
    return 0
  fi

  packages="$(fedora_overlap_packages)"
  if [ -z "$packages" ]; then
    log "No overlapping Fedora RPM packages detected."
    return 0
  fi

  log ""
  log "Fedora RPM packages also provided by rang:"
  printf '  %s\n' $packages

  if [ "$ASSUME_YES" -ne 1 ] && [ -t 0 ]; then
    printf "Remove these Fedora packages now? [y/N]: "
    IFS= read -r reply
    case "$reply" in
      y|Y|yes|YES) ;;
      *)
        log "Skipping Fedora package removal."
        return 0
        ;;
    esac
  fi

  set -- $packages
  if [ "$(id -u)" -eq 0 ]; then
    dnf remove -y "$@"
  else
    sudo dnf remove -y "$@"
  fi
}

apply_home_manager() {
  export RANG_THEME="$THEME"
  load_nix_env || install_nix
  ensure_nix_features

  if has_cmd home-manager; then
    log "Applying Home Manager via installed home-manager"
    home-manager switch -b "$BACKUP_EXT" --impure --flake "path:$DOTFILES_DIR#default"
    return 0
  fi

  if ! has_cmd nix; then
    log "error: nix is not available in this shell"
    if [ -r "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
      log "       run: . \"$HOME/.nix-profile/etc/profile.d/nix.sh\""
    fi
    log "       or open a new shell and rerun ./bootstrap.sh"
    exit 1
  fi

  log "Applying Home Manager via nix run"
  run_nix run github:nix-community/home-manager -- switch -b "$BACKUP_EXT" --impure --flake "path:$DOTFILES_DIR#default"
}

reload_runtime() {
  log ""
  log "Reloading live programs for theme: $THEME"

  if has_cmd swaymsg && wm_is_running sway; then
    swaymsg reload >/dev/null 2>&1 && log "  reloaded: sway" || log "  warn: sway reload failed"
  fi

  if has_cmd tmux && tmux info >/dev/null 2>&1; then
    tmux source-file ~/.tmux.conf \; refresh-client -S >/dev/null 2>&1 \
      && log "  reloaded: tmux" \
      || log "  warn: tmux reload failed"
  fi

  if has_cmd xmonad && wm_is_running xmonad; then
    if xmonad --recompile >/dev/null 2>&1; then
      xmonad --restart >/dev/null 2>&1 && log "  reloaded: xmonad" || log "  warn: xmonad restart failed"
    else
      log "  warn: xmonad recompile failed"
    fi
  fi

  if [ -f "$HOME/.config/alacritty/alacritty.toml" ]; then
    touch "$HOME/.config/alacritty/alacritty.toml" "$HOME/.config/alacritty/theme.toml" 2>/dev/null || true
    log "  nudged: alacritty"
  fi

  if [ -f "$HOME/.config/ghostty/config" ]; then
    touch "$HOME/.config/ghostty/config" "$HOME/.config/ghostty/theme" 2>/dev/null || true
    log "  nudged: ghostty"
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --theme)
      shift
      [ "$#" -gt 0 ] || {
        log "error: --theme requires a value"
        exit 1
      }
      THEME="$1"
      ;;
    --yes) ASSUME_YES=1 ;;
    --remove-fedora-overlap) REMOVE_FEDORA_OVERLAP=1 ;;
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
log "Applying rang with theme: $THEME"
migrate_legacy_links
apply_home_manager
repair_repo_sources
migrate_legacy_links
apply_home_manager
remove_fedora_overlap
reload_runtime
log ""
log "rang applied."

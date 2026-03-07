#!/usr/bin/env sh
set -eu

SUPPORTED_APPS="alacritty ghostty nvim ripgrep zsh firefox claude codex opecode"

usage() {
  cat <<USAGE
Usage:
  ./apps/install.sh list
  ./apps/install.sh install <app...>
  ./apps/install.sh install all

Supported apps:
  $SUPPORTED_APPS
USAGE
}

log() { printf '%s\n' "$*"; }
err() { printf 'error: %s\n' "$*" >&2; }

has_cmd() { command -v "$1" >/dev/null 2>&1; }

pkg_manager() {
  if has_cmd brew; then printf 'brew'; return 0; fi
  if has_cmd apt-get; then printf 'apt'; return 0; fi
  if has_cmd dnf; then printf 'dnf'; return 0; fi
  if has_cmd pacman; then printf 'pacman'; return 0; fi
  if has_cmd zypper; then printf 'zypper'; return 0; fi
  printf 'none'
}

install_with_pkg_manager() {
  manager="$1"
  package="$2"

  case "$manager" in
    brew)   brew install "$package" ;;
    apt)    sudo apt-get update && sudo apt-get install -y "$package" ;;
    dnf)    sudo dnf install -y "$package" ;;
    pacman) sudo pacman -S --noconfirm "$package" ;;
    zypper) sudo zypper install -y "$package" ;;
    *)      err "no supported package manager found"; return 1 ;;
  esac
}

install_npm_global() {
  package="$1"
  if ! has_cmd npm; then
    err "npm is required for '$package'. Install Node.js first."
    return 1
  fi
  npm install -g "$package"
}

install_app() {
  app="$1"
  manager="$(pkg_manager)"

  case "$app" in
    alacritty)
      case "$manager" in
        brew) install_with_pkg_manager "$manager" alacritty ;;
        apt|dnf|pacman|zypper) install_with_pkg_manager "$manager" alacritty ;;
        *) err "cannot auto-install alacritty on this system"; return 1 ;;
      esac
      ;;
    ghostty)
      case "$manager" in
        brew) brew install --cask ghostty ;;
        *)
          err "ghostty auto-install is only wired for Homebrew right now"
          err "manual: https://ghostty.org/docs/install"
          return 1
          ;;
      esac
      ;;
    nvim)
      case "$manager" in
        brew) install_with_pkg_manager "$manager" neovim ;;
        apt|dnf|pacman|zypper) install_with_pkg_manager "$manager" neovim ;;
        *) err "cannot auto-install nvim on this system"; return 1 ;;
      esac
      ;;
    ripgrep)
      install_with_pkg_manager "$manager" ripgrep
      ;;
    zsh)
      install_with_pkg_manager "$manager" zsh
      ;;
    firefox)
      case "$manager" in
        brew) brew install --cask firefox ;;
        apt|dnf|pacman|zypper) install_with_pkg_manager "$manager" firefox ;;
        *) err "cannot auto-install firefox on this system"; return 1 ;;
      esac
      ;;
    claude)
      install_npm_global "${CLAUDE_PKG:-@anthropic-ai/claude-code}"
      ;;
    codex)
      install_npm_global "${CODEX_PKG:-@openai/codex}"
      ;;
    opecode)
      install_npm_global "${OPECODE_PKG:-opecode}"
      ;;
    *)
      err "unsupported app: $app"
      return 1
      ;;
  esac
}

is_supported() {
  app="$1"
  for candidate in $SUPPORTED_APPS; do
    [ "$candidate" = "$app" ] && return 0
  done
  return 1
}

if [ "$#" -lt 1 ]; then
  usage
  exit 1
fi

cmd="$1"
shift

case "$cmd" in
  list)
    for app in $SUPPORTED_APPS; do
      printf '%s\n' "$app"
    done
    ;;
  install)
    [ "$#" -gt 0 ] || { err "install requires at least one app"; usage; exit 1; }

    targets="$*"
    if [ "$1" = "all" ]; then
      targets="$SUPPORTED_APPS"
    fi

    failed=""
    for app in $targets; do
      if ! is_supported "$app"; then
        err "unsupported app: $app"
        failed="$failed $app"
        continue
      fi

      log "==> Installing $app"
      if ! install_app "$app"; then
        failed="$failed $app"
      fi
    done

    if [ -n "$failed" ]; then
      err "failed:$failed"
      exit 1
    fi

    log "All requested apps installed successfully."
    ;;
  *)
    err "unknown command: $cmd"
    usage
    exit 1
    ;;
esac

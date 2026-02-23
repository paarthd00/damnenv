#!/usr/bin/env sh
set -eu

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"

link() {
  src="$DOTFILES_DIR/$1"
  dst="$HOME/$2"

  mkdir -p "$(dirname "$dst")"

  if [ -L "$dst" ]; then
    rm -f "$dst"
  elif [ -e "$dst" ]; then
    mv "$dst" "$dst.bak-$(date +%Y%m%d-%H%M%S)"
  fi

  ln -s "$src" "$dst"
  echo "linked $dst -> $src"
}

link .zshrc .zshrc
link .zprofile .zprofile
link .zshenv .zshenv
link .p10k.zsh .p10k.zsh
link .config/tmux/tmux.conf.local .config/tmux/tmux.conf.local
link .config/alacritty .config/alacritty

echo "skipping ~/.gitconfig (keep Git identity local/private)"

if [ -L "$HOME/.config/nvim" ]; then
  rm -f "$HOME/.config/nvim"
elif [ -e "$HOME/.config/nvim" ]; then
  mv "$HOME/.config/nvim" "$HOME/.config/nvim.bak-$(date +%Y%m%d-%H%M%S)"
fi
mkdir -p "$HOME/.config"
ln -s "$DOTFILES_DIR/.config/nvim" "$HOME/.config/nvim"
echo "linked $HOME/.config/nvim -> $DOTFILES_DIR/.config/nvim"

# dotfiles

Personal Linux dotfiles managed with symlinks.

## Quick start

```sh
git clone git@github.com:paarthd00/dotfiles.git ~/dotfiles
cd ~/dotfiles
./bootstrap.sh
```

`bootstrap.sh` is the main installer and has no Haskell/Cabal dependency.
It links dotfiles, asks for a theme (default: `night-owl`), and applies theme files for Alacritty, tmux, and Neovim.

## Make targets

```sh
make bootstrap              # full setup + interactive theme selection
make run                    # alias for make bootstrap
make theme THEME=night-owl  # apply theme only
make theme THEME=rose-pine
```

## Bootstrap options

```sh
./bootstrap.sh --help
./bootstrap.sh --theme tokyo-night --yes
./bootstrap.sh --theme rose-pine-light --theme-only --yes
```

Options:

- `--theme THEME` apply a specific theme
- `--yes` non-interactive mode (`night-owl` default if theme not set)
- `--theme-only` only switch theme links, skip base dotfile linking

## Supported themes

- `night-owl`
- `rose-pine`
- `rose-pine-light`
- `tokyo-night`
- `quiet-light`

Theme assets are under `themes/<theme>/` and include:

- `alacritty.toml`
- `tmux.conf`
- `nvim-theme.lua`

## What gets linked

- `~/.zshrc`, `~/.zprofile`, `~/.zshenv`, `~/.p10k.zsh`
- `~/.config/alacritty` -> `.config/alacritty`
- `~/.config/nvim` -> `.config/nvim`
- `~/.tmux.conf` -> `themes/<theme>/tmux.conf`
- `~/.config/alacritty/alacritty.toml` -> `themes/<theme>/alacritty.toml`
- `~/.config/nvim/lua/paarth/theme.lua` -> `themes/<theme>/nvim-theme.lua`
- `~/.codex/config.toml` -> `codex/config.toml`
- `~/.claude.json` -> `claude/config.json`
- Optional: `~/.xmonad/xmonad.hs` if present in repo

Existing targets are replaced in place (no `.bak-*` backups).

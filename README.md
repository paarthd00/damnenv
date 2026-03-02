# dotfiles

Personal Linux dotfiles managed with symlinks.

## Setup

```sh
git clone git@github.com:paarthd00/dotfiles.git ~/dotfiles
cd ~/dotfiles
./bootstrap.sh
```

`bootstrap.sh` links all dotfiles, prompts for a theme (default: `night-owl`), applies theme files for Alacritty/tmux/Neovim, and updates the Claude theme and sets COLORFGBG for TUI apps.

## Options

```sh
./bootstrap.sh --theme night-owl   # skip prompt, use specific theme
./bootstrap.sh --yes               # non-interactive, defaults to night-owl
./bootstrap.sh --theme-only        # re-apply theme links only
./bootstrap.sh --help
```

## Themes

- `night-owl`
- `rose-pine`
- `rose-pine-light`
- `tokyo-night`
- `quiet-light`

Theme assets live under `themes/<theme>/` — `alacritty.toml`, `tmux.conf`, `nvim-theme.lua`.

## What gets linked

| Link | Source |
|------|--------|
| `~/.zshrc` | `.zshrc` |
| `~/.zprofile` | `.zprofile` |
| `~/.zshenv` | `.zshenv` |
| `~/.p10k.zsh` | `.p10k.zsh` |
| `~/.config/alacritty/` | `.config/alacritty/` |
| `~/.config/nvim/` | `.config/nvim/` |
| `~/.tmux.conf` | `.tmux.conf` |
| `~/.codex/config.toml` | `codex/config.toml` |
| `~/.claude.json` | `claude/config.json` |
| `~/.config/alacritty/theme.toml` | `themes/<theme>/alacritty.toml` |
| `~/.tmux-theme.conf` | `themes/<theme>/tmux.conf` |
| `~/.config/nvim/lua/paarth/theme.lua` | `themes/<theme>/nvim-theme.lua` |

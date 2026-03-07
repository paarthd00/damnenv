# Window Manger Theme

Personal Linux config with theme switching for Sway and XMonad.

## Prerequisites

### Terminal emulator (one of)
- [Alacritty](https://alacritty.org) — primary terminal, all themes fully tested
- [Ghostty](https://ghostty.org) — also supported (theme applied via alacritty config only)

### Window manager (one or both)
- [Sway](https://swaywm.org) — Wayland tiling WM; themes update waybar, wofi, and sway colors
- [XMonad](https://xmonad.org) — X11 tiling WM; themes update xmobar colors and the Haskell PP config

### Required tools
| Tool | Purpose |
|------|---------|
| `git` | Clone this repo and install OMZ plugins |
| `curl` | Install Oh My Zsh |
| [`ripgrep`](https://github.com/BurntSushi/ripgrep#installation) | Neovim live grep via Telescope — **required for `:Telescope live_grep`** |

The bootstrap will detect missing tools and offer to install `ripgrep` automatically.

### Optional tools
| Tool | Purpose |
|------|---------|
| `zsh` | Zsh shell setup with Oh My Zsh + Powerlevel10k |
| `tmux` | Terminal multiplexer with themed statusbar |
| `fd` / `fdfind` | Faster file search for fzf |
| `bat` | Syntax-highlighted file previews in fzf |
| `exa` | Better `ls` (falls back to `colorls` or `ls`) |

---

## Quick start

```sh
git clone git@github.com:paarthd00/dotfiles.git ~/WM-Theme
cd ~/WM-Theme
./bootstrap.sh
```

The script will:
1. Check for required dependencies (and offer to install `ripgrep`)
2. Prompt for a theme
3. Ask which components to set up (Zsh, Oh My Zsh, plugins, tmux)
4. Link all configs and apply the selected theme
5. Reload Sway or restart XMonad if running

---

## Options

```sh
./bootstrap.sh --theme tokyo-night   # skip prompt, apply a specific theme
./bootstrap.sh --yes                 # non-interactive, defaults to night-owl
./bootstrap.sh --theme-only          # re-apply theme links only, skip dotfile links
```

---

## Themes

All themes are fully tested with Sway, XMonad, Neovim, Alacritty, tmux, waybar, and wofi.

| Theme | Style |
|-------|-------|
| `night-owl` | Dark — blue/teal, default |
| `rose-pine` | Dark — muted purple/rose |
| `rose-pine-light` | Light — warm parchment |
| `tokyo-night` | Dark — deep blue/purple |
| `quiet-light` | Light — minimal, neutral |

Each theme provides: `alacritty.toml`, `tmux.conf`, `nvim-theme.lua`, `sway-colors.conf`,
`waybar-colors.css`, `wofi-colors.css`, `xmobarrc`, `xmonad-colors.hs`.

---

## Auto-detection

The bootstrap detects what is installed and only links what applies — nothing is installed
or forced. Re-running is always safe.

| Tool | Behaviour if installed | Behaviour if missing |
|------|----------------------|---------------------|
| `zsh` | Links `home/profile/zsh_rc.zsh`, `zsh_profile.zsh`, `zsh_env.zsh`, `zsh_p10k.zsh` | Skipped |
| `tmux` | Links `home/profile/zsh_tmux_conf.zsh` + theme file, reloads if running | Skipped |
| `alacritty` | Links alacritty config + theme | Skipped |
| Sway | Links `managers/sway`, `managers/sway/waybar`, `wofi` configs + theme, reloads if running | Skipped |
| XMonad | Links `xmonad.hs`, `xmobarrc`, `Colors.hs`, recompiles if running | Skipped |

### Oh My Zsh plugins (install separately if desired)

The `.zshrc` uses these plugins — install them manually into `$ZSH_CUSTOM/plugins/`:

| Plugin | Install |
|--------|---------|
| `zsh-autosuggestions` | `git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions` |
| `fast-syntax-highlighting` | `git clone https://github.com/zdharma-continuum/fast-syntax-highlighting $ZSH_CUSTOM/plugins/fast-syntax-highlighting` |
| `zsh-autocomplete` | `git clone https://github.com/marlonrichert/zsh-autocomplete $ZSH_CUSTOM/plugins/zsh-autocomplete` |
| Powerlevel10k | `git clone --depth=1 https://github.com/romkatv/powerlevel10k $ZSH_CUSTOM/themes/powerlevel10k` |

---

## What gets linked

| Destination | Source |
|-------------|--------|
| `~/.zshrc` | `home/profile/zsh_rc.zsh` |
| `~/.zprofile` | `home/profile/zsh_profile.zsh` |
| `~/.zshenv` | `home/profile/zsh_env.zsh` |
| `~/.p10k.zsh` | `home/profile/zsh_p10k.zsh` |
| `~/.config/alacritty/` | `home/config/alacritty/` |
| `~/.config/nvim/` | `home/config/nvim/` |
| `~/.config/wofi/` | `home/config/wofi/` |
| `~/.config/sway/` | `managers/sway/` |
| `~/.config/waybar/` | `managers/sway/waybar/` |
| `~/.tmux.conf` | `home/profile/zsh_tmux_conf.zsh` |
| `~/.xmonad/xmonad.hs` | `managers/xmonad/xmonad.hs` |
| `~/.codex/config.toml` | `codex/config.toml` |
| `~/.claude.json` | `claude/config.json` |

### Theme links (applied on every run)

| Destination | Source |
|-------------|--------|
| `~/.config/alacritty/theme.toml` | `themes/<theme>/alacritty.toml` |
| `~/.tmux-theme.conf` | `themes/<theme>/tmux.conf` |
| `~/.config/nvim/lua/paarth/theme.lua` | `themes/<theme>/nvim-theme.lua` |
| `~/.config/sway/colors.conf` | `themes/<theme>/sway-colors.conf` *(Sway only)* |
| `~/.config/waybar/style.css` | `themes/<theme>/waybar-colors.css` + `managers/sway/waybar/style-base.css` *(Sway only)* |
| `~/.config/wofi/style.css` | `themes/<theme>/wofi-colors.css` + `home/config/wofi/style-base.css` *(Sway only)* |
| `~/xmobarrc` | `themes/<theme>/xmobarrc` *(XMonad only)* |
| `~/.xmonad/lib/Colors.hs` | `themes/<theme>/xmonad-colors.hs` *(XMonad only)* |

---

## XMonad notes

`xmonad.hs` imports a `Colors` module from `~/.xmonad/lib/Colors.hs`. This file is written
by the bootstrap per theme. After switching themes, xmonad is automatically recompiled and
restarted if it is currently running.

The `Colors.hs` module exposes: `colorBg`, `colorFg`, `colorCurrent`, `colorVisible`,
`colorHidden`, `colorHiddenNoWin`, `colorTitle`, `colorLayout`, `colorDate`, `colorTime`.

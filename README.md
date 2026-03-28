# damnenv

`damnenv` is a Nix-first desktop and editor setup with shared theming for Sway, XMonad, Neovim, tmux, Alacritty, Ghostty, Wofi, and Waybar.

## Quick Start

Clone it wherever you want. Using `~/damnenv` keeps the naming consistent:

```sh
git clone git@github.com:paarthd00/dotfiles.git ~/damnenv
cd ~/damnenv
./bootstrap.sh
```

On a fresh Fedora machine, `bootstrap.sh` will install official single-user Nix automatically if `nix` is missing, then continue with Home Manager.

`bootstrap.sh` then:

1. choose a theme
2. export `DAMNENV_THEME=<theme>`
3. run Home Manager with flake support enabled
4. optionally remove overlapping Fedora RPM packages with `--remove-fedora-overlap`
5. reload live programs like Sway, tmux, and XMonad when possible

Bootstrap runs Home Manager with backup mode enabled. Existing conflicting files are moved aside with the extension `.damnenv-backup` by default.

Before applying, bootstrap also removes legacy repo-managed symlinks from `~/.config/...` and restores repo source files if an older Home Manager run accidentally replaced them with dead Nix store links.

If you want to skip the prompt:

```sh
./bootstrap.sh --theme tokyo-night
./bootstrap.sh --yes
./bootstrap.sh --remove-fedora-overlap
```

You can also call Home Manager directly:

```sh
DAMNENV_THEME=tokyo-night nix --extra-experimental-features "nix-command flakes" run github:nix-community/home-manager -- switch --impure --flake "path:$PWD#default"
```

If you install Nix outside `bootstrap.sh` and your current shell still says `nix: command not found`, it has not loaded the Nix profile yet. Either open a new shell or run:

```sh
. "$HOME/.nix-profile/etc/profile.d/nix.sh"
```

Then rerun `./bootstrap.sh`.

`--remove-fedora-overlap` is intentionally opt-in. It only targets overlapping user-space RPM packages it can detect locally and deliberately skips the distro `zsh` package until your login shell no longer points at `/usr/bin/zsh`.

## What Nix Manages

The Home Manager module lives at `nix/modules/damnenv.nix`. It manages:

- packages from `nix/package-set.nix`
- `home/profile/zsh_*`
- `home/config/alacritty`
- `home/config/ghostty`
- `home/config/nvim` plus the selected theme file
- `home/config/wofi` plus generated `style.css`
- `window-managers/sway/*` plus generated `waybar/style.css`
- `window-managers/xmonad/xmonad.hs`
- theme files for Alacritty, Ghostty, tmux, Neovim, Sway, Waybar, Wofi, Xmobar, and XMonad
- `~/.theme-env` and `COLORFGBG`

Package groups in `nix/package-set.nix`:

- `common` for base CLI tools
- `desktop` for terminal/editor apps
- `firefox` for the browser
- `aiCli` for Claude Code, Codex, and Opencode
- `sway`, `xmonad`, and `fonts` for WM/runtime dependencies

The flake also exposes a package bundle as `.#damnenv` and `.#damnenv-packages` if you want the tool bundle without the full Home Manager setup.

Fedora note:

- `nix/package-set.nix` intentionally excludes system services such as NetworkManager, Bluetooth, and PipeWire/PulseAudio service packages.
- Those remain distro-managed on Fedora even if the user-facing apps and configs come from Nix.
- The Nix package set is meant to replace user tools first, not your base system services.

## Theme Selection

The flake default theme is `night-owl`. The active theme can be set in either of these ways:

- run `./bootstrap.sh --theme tokyo-night`
- set `DAMNENV_THEME=tokyo-night` before `home-manager switch`
- hardcode `damnenv.theme = "tokyo-night";` in `flake.nix`

Available theme values:

- `night-owl`
- `pitch-black`
- `quiet-light`
- `rose-pine`
- `rose-pine-light`
- `tokyo-night`

Each theme provides:

- `alacritty.toml`
- `ghostty.conf`
- `nvim-theme.lua`
- `sway-colors.conf`
- `tmux.conf`
- `waybar-colors.css`
- `wofi-colors.css`
- `xmobarrc`
- `xmonad-colors.hs`

## Runtime Behavior

`bootstrap.sh` no longer links files directly. Home Manager owns the files; bootstrap only applies a theme and nudges running programs to reload.

On a successful apply:

- Sway is reloaded with `swaymsg reload` when running
- tmux reloads `~/.tmux.conf` when running
- XMonad recompiles and restarts when running
- Alacritty and Ghostty config files are touched to encourage live reload

## Managed Files

Primary Home Manager outputs:

- `~/.zshrc` from `home/profile/zsh_rc.zsh`
- `~/.zprofile` from `home/profile/zsh_profile.zsh`
- `~/.zshenv` from `home/profile/zsh_env.zsh`
- `~/.p10k.zsh` from `home/profile/zsh_p10k.zsh`
- `~/.tmux.conf` from `home/profile/zsh_tmux_conf.zsh`
- `~/.tmux-theme.conf` from `themes/<theme>/tmux.conf`
- `~/.config/alacritty/alacritty.toml` and `theme.toml`
- `~/.config/ghostty/config` and `theme`
- `~/.config/nvim/...`
- `~/.config/wofi/config` and generated `style.css`
- `~/.config/sway/...`
- `~/.config/waybar/config`, `quick-settings-menu.xml`, and generated `style.css`
- `~/.xmonad/xmonad.hs`
- `~/.xmonad/lib/Colors.hs`
- `~/xmobarrc`

## Notes

The zsh startup now sources Powerlevel10k, zsh-autocomplete, zsh-autosuggestions, zsh-syntax-highlighting, and fzf integration from Nix store paths. The remaining non-Nix piece is the Fedora login shell entry itself, so keep the distro `zsh` package until you switch your account shell away from `/usr/bin/zsh`.

# apps

App installer entrypoint:

```sh
./apps/install.sh list
./apps/install.sh install nvim ripgrep zsh
./apps/install.sh install all
```

Supported app ids:

- `alacritty`
- `ghostty`
- `nvim`
- `ripgrep`
- `zsh`
- `firefox`
- `claude`
- `codex`
- `opecode`

Notes:

- `claude`, `codex`, and `opecode` use global `npm` installs.
- Override npm package names with env vars if needed:
  - `CLAUDE_PKG`
  - `CODEX_PKG`
  - `OPECODE_PKG`

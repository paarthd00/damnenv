{ lib, pkgs }:
let
  # Wrap a package so it runs through nixGL, fixing OpenGL/EGL on non-NixOS.
  # AMD and Intel both use Mesa, so nixGLIntel is the right wrapper.
  nixGLWrap = pkg:
    let
      exeName = pkg.meta.mainProgram or (lib.getName pkg);
    in
    pkgs.writeShellScriptBin exeName ''
      exec ${pkgs.nixgl.nixGLIntel}/bin/nixGLIntel ${pkg}/bin/${exeName} "$@"
    '';

  zedCli = pkgs.writeShellScriptBin "zed" ''
    if [ -S "''${XDG_RUNTIME_DIR}/wayland-0" ]; then
      export WAYLAND_DISPLAY=wayland-0
    else
      unset WAYLAND_DISPLAY
    fi
    exec ${pkgs.nixgl.nixGLIntel}/bin/nixGLIntel ${pkgs.zed-editor}/bin/zeditor "$@"
  '';

  common = with pkgs; [
    git
    curl
    neovim
    nodejs
    ripgrep
    zsh
    tmux
    fzf
    fd
    bat
    eza
  ];

  desktop = with pkgs; [
    (nixGLWrap alacritty)
    (nixGLWrap ghostty)
    (nixGLWrap zed-editor)
    zedCli
  ];

  firefox = [
    (nixGLWrap pkgs.firefox)
  ];

  aiCli = with pkgs; [
    claude-code
    codex
    opencode
  ];

  # User-space Wayland tools that make sense in a Home Manager profile.
  # Fedora should continue to own services like NetworkManager, Bluetooth,
  # PipeWire/WirePlumber, and related system packages.
  sway = [
    (nixGLWrap pkgs.sway)        # wlroots compositor — needs EGL/DRI access
    pkgs.waybar                  # GTK, software rendering OK
    pkgs.wofi                    # GTK, software rendering OK
    pkgs.mako                    # no rendering
    pkgs.swayidle                # no rendering
    (nixGLWrap pkgs.swaylock)    # EGL lock screen — must not fail
    pkgs.pavucontrol             # GTK, software rendering OK
    pkgs.brightnessctl
    pkgs.wl-clipboard
    pkgs.xdg-utils
  ];

  xmonad = [
    pkgs.haskellPackages.xmonad
    pkgs.haskellPackages.xmonad-contrib
    pkgs.haskellPackages.xmobar
  ];

  fonts = with pkgs; [
    fira-code
    nerd-fonts.jetbrains-mono
  ];
in
{
  inherit common desktop firefox aiCli sway xmonad fonts;

  full = lib.unique (common ++ desktop ++ firefox ++ aiCli ++ sway ++ fonts ++ xmonad);
}

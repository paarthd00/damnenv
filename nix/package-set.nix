{ lib, pkgs }:
let
  isLinux = pkgs.stdenv.isLinux;
  # Wrap a package so it runs through nixGL, fixing OpenGL/EGL on non-NixOS.
  # AMD and Intel both use Mesa, so nixGLIntel is the right wrapper.
  nixGLWrap = if isLinux then (pkg:
    let
      exeName = pkg.meta.mainProgram or (lib.getName pkg);
    in
    pkgs.writeShellScriptBin exeName ''
      exec ${pkgs.nixgl.nixGLIntel}/bin/nixGLIntel ${pkg}/bin/${exeName} "$@"
    '')
  else
    (pkg: pkg);

  zedCli = if isLinux then
    pkgs.writeShellScriptBin "zed" ''
    exec ${pkgs.nixgl.nixGLIntel}/bin/nixGLIntel ${pkgs.zed-editor}/bin/zeditor "$@"
    ''
  else
    null;

  common = with pkgs; [
    git
    curl
    jq
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

  desktop = if isLinux then (with pkgs; [
    (nixGLWrap alacritty)
    (nixGLWrap ghostty)
    (nixGLWrap zed-editor)
    zedCli
  ]) else [ ];

  firefox = if isLinux then [ (nixGLWrap pkgs.firefox) ] else [ ];

  aiCli = with pkgs; [
    claude-code
    codex
    opencode
  ];

  # User-space Wayland tools that make sense in a Home Manager profile.
  # Fedora should continue to own services like NetworkManager, Bluetooth,
  # PipeWire/WirePlumber, and related system packages.
  sway = if isLinux then [
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
  ] else [ ];

  xmonad = if isLinux then [
    pkgs.haskellPackages.xmonad
    pkgs.haskellPackages.xmonad-contrib
    pkgs.haskellPackages.xmobar
  ] else [ ];

  fonts = with pkgs; [
    fira-code
    nerd-fonts.jetbrains-mono
  ];
in
{
  inherit common desktop firefox aiCli sway xmonad fonts;

  full = lib.unique (common ++ desktop ++ firefox ++ aiCli ++ sway ++ fonts ++ xmonad);
}

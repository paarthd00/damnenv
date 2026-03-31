{ config, lib, pkgs, repoRoot, ... }:
let
  cfg = config.damnenv;
  repo = repoRoot;
  packageSet = import (repoRoot + "/nix/package-set.nix") { inherit lib pkgs; };
  t = builtins.fromJSON (builtins.readFile (repo + "/themes/${cfg.theme}.json"));
  lightTheme = lib.hasInfix "light" cfg.theme;
  colorFgBg = if lightTheme then "0;15" else "15;0";
  nvimSource = lib.cleanSourceWith {
    src = repo + "/home/config/nvim";
    filter = path: _type: baseNameOf path != "theme.lua";
  };

  # Convert #rrggbb → "r, g, b" for CSS rgba()
  hexToRgb = hex:
    let
      h  = builtins.substring 1 6 hex;
      hd = c:
             if c == "0" then 0 else if c == "1" then 1 else if c == "2" then 2
        else if c == "3" then 3 else if c == "4" then 4 else if c == "5" then 5
        else if c == "6" then 6 else if c == "7" then 7 else if c == "8" then 8
        else if c == "9" then 9 else if c == "a" || c == "A" then 10
        else if c == "b" || c == "B" then 11 else if c == "c" || c == "C" then 12
        else if c == "d" || c == "D" then 13 else if c == "e" || c == "E" then 14
        else 15;
      byte = s: (hd (builtins.substring 0 1 s)) * 16 + (hd (builtins.substring 1 1 s));
    in "${toString (byte (builtins.substring 0 2 h))}, "
     + "${toString (byte (builtins.substring 2 2 h))}, "
     + "${toString (byte (builtins.substring 4 2 h))}";

  alacrittyTheme = ''
    [colors.primary]
    background = "${t.background}"
    foreground = "${t.foreground}"

    [colors.cursor]
    text   = "${t.cursor_text}"
    cursor = "${t.cursor}"

    [colors.selection]
    background = "${t.selection_bg}"

    [colors.normal]
    black   = "${t.normal.black}"
    red     = "${t.normal.red}"
    green   = "${t.normal.green}"
    yellow  = "${t.normal.yellow}"
    blue    = "${t.normal.blue}"
    magenta = "${t.normal.magenta}"
    cyan    = "${t.normal.cyan}"
    white   = "${t.normal.white}"

    [colors.bright]
    black   = "${t.bright.black}"
    red     = "${t.bright.red}"
    green   = "${t.bright.green}"
    yellow  = "${t.bright.yellow}"
    blue    = "${t.bright.blue}"
    magenta = "${t.bright.magenta}"
    cyan    = "${t.bright.cyan}"
    white   = "${t.bright.white}"
  '';

  ghosttyTheme = ''
    background = ${t.background}
    foreground = ${t.foreground}
    cursor-color = ${t.cursor}
    selection-background = ${t.selection_bg}
    palette = 0=${t.normal.black}
    palette = 1=${t.normal.red}
    palette = 2=${t.normal.green}
    palette = 3=${t.normal.yellow}
    palette = 4=${t.normal.blue}
    palette = 5=${t.normal.magenta}
    palette = 6=${t.normal.cyan}
    palette = 7=${t.normal.white}
    palette = 8=${t.bright.black}
    palette = 9=${t.bright.red}
    palette = 10=${t.bright.green}
    palette = 11=${t.bright.yellow}
    palette = 12=${t.bright.blue}
    palette = 13=${t.bright.magenta}
    palette = 14=${t.bright.cyan}
    palette = 15=${t.bright.white}
  '';

  swayColors = ''
    set $bg      ${t.background}
    set $bg2     ${t.bg2}
    set $border  ${t.border}
    set $fg      ${t.foreground}
    set $fg_dim  ${t.fg_dim}
    set $accent  ${t.accent}
    set $lock_bg ${builtins.substring 1 6 t.background}
  '';

  waybarColors = ''
    @define-color bg     ${t.background};
    @define-color bg_bar rgba(${hexToRgb t.background}, 0.95);
    @define-color bg2    ${t.bg2};
    @define-color border ${t.border};
    @define-color fg     ${t.foreground};
    @define-color fg_dim ${t.fg_dim};
  '';

  wofiColors = ''
    @define-color bg     ${t.background};
    @define-color bg2    ${t.bg2};
    @define-color border ${t.border};
    @define-color fg     ${t.foreground};
    @define-color fg_dim ${t.fg_dim};
  '';

  waybarStyle = waybarColors + "\n" + builtins.readFile (repo + "/window-managers/sway/waybar/style-base.css");
  wofiStyle   = wofiColors   + "\n" + builtins.readFile (repo + "/home/config/wofi/style-base.css");

  tmuxTheme = ''
    set -g status-style                "fg=${t.foreground},bg=${t.background}"
    set -g message-style               "fg=${t.background},bg=${t.normal.blue}"
    set -g message-command-style       "fg=${t.background},bg=${t.normal.magenta}"
    set -g mode-style                  "fg=${t.background},bg=${t.normal.yellow}"
    set -g clock-mode-colour           "${t.normal.blue}"

    set -g pane-border-style           "fg=${t.bright.black}"
    set -g pane-active-border-style    "fg=${t.normal.blue}"

    set -g window-status-style         "fg=${t.fg_dim},bg=${t.background}"
    set -g window-status-current-style "fg=${t.background},bg=${t.normal.blue},bold"
    set -g window-status-activity-style "fg=${t.normal.green},bg=${t.background},bold"
    set -g window-status-bell-style    "fg=${t.background},bg=${t.normal.red},bold"

    set -g status-left-length  32
    set -g status-right-length 64
    set -g status-left-style   "fg=${t.background},bg=${t.normal.blue},bold"
    set -g status-left         "#S "
    set -g status-right-style  "fg=${t.background},bg=${t.normal.magenta},bold"
    set -g status-right        "%Y-%m-%d %H:%M "
  '';

  nvimTheme = ''
    return {
      colorscheme = '${t.nvim.colorscheme}',
      transparent = ${lib.boolToString t.nvim.transparent},
    }
  '';

  xmobarrcContent = ''
    Config
      { font     = "xft:Fira Code:size=11:antialias=true"
      , bgColor  = "${t.background}"
      , fgColor  = "${t.foreground}"
      , position = TopSize L 100 26
      , border   = NoBorder
      , commands =
          [ Run UnsafeXPropertyLog "_XMONAD_LOG"
          , Run Com "sh"
              [ "-c"
              , "cap=$(cat /sys/class/power_supply/BAT0/capacity); status=$(cat /sys/class/power_supply/BAT0/status); if [ \"$status\" = \"Charging\" ] || [ \"$status\" = \"Full\" ]; then echo \"AC ''${cap}%\"; else echo \"BAT ''${cap}%\"; fi"
              ] "battery" 50
          , Run Date "<fc=${t.xmonad.current}>%a %d %b</fc>  <fc=${t.normal.magenta}>%H:%M</fc>" "date" 50
          ]
      , template = "  %_XMONAD_LOG%  }{ %battery%  %date%  "
      }
  '';

  xmonadColors = ''
    module Colors where

    colorBg, colorFg :: String
    colorBg          = "${t.background}"
    colorFg          = "${t.foreground}"

    colorCurrent, colorVisible, colorHidden, colorHiddenNoWin :: String
    colorCurrent     = "${t.xmonad.current}"
    colorVisible     = "${t.xmonad.visible}"
    colorHidden      = "${t.xmonad.hidden}"
    colorHiddenNoWin = "${t.xmonad.hidden_no_win}"

    colorTitle, colorLayout :: String
    colorTitle       = "${t.xmonad.title}"
    colorLayout      = "${t.xmonad.layout}"

    colorDate, colorTime :: String
    colorDate        = "${t.xmonad.current}"
    colorTime        = "${t.normal.magenta}"
  '';
  selectedPackages =
    packageSet.common
    ++ lib.optionals cfg.packageSets.desktop packageSet.desktop
    ++ lib.optionals cfg.packageSets.firefox packageSet.firefox
    ++ lib.optionals cfg.packageSets.aiCli packageSet.aiCli
    ++ lib.optionals cfg.packageSets.sway packageSet.sway
    ++ lib.optionals cfg.packageSets.xmonad packageSet.xmonad
    ++ lib.optionals cfg.packageSets.fonts packageSet.fonts;
in
{
  options.damnenv = {
    enable = lib.mkEnableOption "damnenv Home Manager integration";

    theme = lib.mkOption {
      type = lib.types.enum [
        "night-owl"
        "pitch-black"
        "quiet-light"
        "rose-pine"
        "rose-pine-light"
        "tokyo-night"
      ];
      default = "night-owl";
      example = "tokyo-night";
      description = "Theme to apply across the managed configs.";
    };

    installPackages = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install the package set through Home Manager.";
    };

    packageSets = {
      desktop = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install desktop apps like Alacritty, Ghostty, and Zed.";
      };

      firefox = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install Firefox.";
      };

      aiCli = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install Claude Code, Codex, and Opencode.";
      };

      sway = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install the Wayland/Sway stack used by this repo.";
      };

      xmonad = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install the XMonad/Xmobar stack used by this repo.";
      };

      fonts = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install Fira Code and JetBrains Mono Nerd Font.";
      };
    };

    manage = {
      alacritty = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Manage the Alacritty config and theme file.";
      };

      ghostty = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Manage the Ghostty config and theme file.";
      };

      nvim = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Manage the Neovim config and selected theme file.";
      };

      sway = lib.mkOption {
        type = lib.types.bool;
        default = pkgs.stdenv.isLinux;
        description = "Manage the Sway, Waybar, and Wofi configs.";
      };

      tmux = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Manage the tmux config and theme include.";
      };

      xmonad = lib.mkOption {
        type = lib.types.bool;
        default = pkgs.stdenv.isLinux;
        description = "Manage the XMonad config and theme files.";
      };

      zsh = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Manage the zsh profile files from home/profile.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = if cfg.installPackages then lib.unique selectedPackages else [ ];

    home.sessionVariables = {
      COLORFGBG = colorFgBg;
    };

    home.file = lib.mkMerge [
      {
        ".theme-env".text = ''
          export COLORFGBG="${colorFgBg}"
        '';
      }

      (lib.optionalAttrs cfg.manage.zsh {
        ".zshrc" = {
          text  = ''
          export DAMNENV_ZSH_POWERLEVEL10K="${pkgs.zsh-powerlevel10k}/share/zsh/themes/powerlevel10k/powerlevel10k.zsh-theme"
          export DAMNENV_ZSH_AUTOCOMPLETE="${pkgs.zsh-autocomplete}/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh"
          export DAMNENV_ZSH_AUTOSUGGESTIONS="${pkgs.zsh-autosuggestions}/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
          export DAMNENV_ZSH_SYNTAX_HIGHLIGHTING="${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
          export DAMNENV_FZF_COMPLETION="${pkgs.fzf}/share/fzf/completion.zsh"
          export DAMNENV_FZF_KEY_BINDINGS="${pkgs.fzf}/share/fzf/key-bindings.zsh"

          ${builtins.readFile (repo + "/home/profile/zsh_rc.zsh")}
          '';
          force = true;
        };
        ".zprofile" = {
          source = repo + "/home/profile/zsh_profile.zsh";
          force = true;
        };
        ".zshenv" = {
          source = repo + "/home/profile/zsh_env.zsh";
          force = true;
        };
        ".p10k.zsh" = {
          source = repo + "/home/profile/zsh_p10k.zsh";
          force = true;
        };
      })

      (lib.optionalAttrs cfg.manage.tmux {
        ".tmux.conf".source = repo + "/home/profile/zsh_tmux_conf.zsh";
        ".tmux-theme.conf" = {
          text  = tmuxTheme;
          force = true;
        };
      })

      (lib.optionalAttrs cfg.manage.xmonad {
        ".xmonad/xmonad.hs".source = repo + "/window-managers/xmonad/xmonad.hs";
        ".xmonad/lib/Colors.hs" = {
          text  = xmonadColors;
          force = true;
        };
        "xmobarrc" = {
          text  = xmobarrcContent;
          force = true;
        };
      })
    ];

  xdg.desktopEntries = lib.mkMerge [
      (lib.optionalAttrs (pkgs.stdenv.isLinux && cfg.packageSets.desktop) {
        zed = {
          name = "Zed";
          genericName = "Text Editor";
          comment = "A high-performance, multiplayer code editor.";
          exec = "zeditor %U";
          icon = "${pkgs.zed-editor}/share/icons/hicolor/512x512/apps/zed.png";
          categories = [ "Utility" "TextEditor" "Development" "IDE" ];
          mimeType = [ "text/plain" "application/x-zerosize" "x-scheme-handler/zed" ];
          startupNotify = true;
          actions = {
            "NewWorkspace" = {
              name = "Open a new workspace";
              exec = "zeditor --new %U";
            };
          };
        };

        alacritty = {
          name = "Alacritty";
          genericName = "Terminal";
          comment = "A fast, cross-platform, OpenGL terminal emulator";
          exec = "alacritty";
          icon = "${pkgs.alacritty}/share/icons/hicolor/scalable/apps/Alacritty.svg";
          categories = [ "System" "TerminalEmulator" ];
          startupNotify = true;
        };

        ghostty = {
          name = "Ghostty";
          genericName = "Terminal";
          comment = "Fast, feature-rich, and cross-platform terminal";
          exec = "ghostty";
          icon = "${pkgs.ghostty}/share/icons/hicolor/256x256/apps/com.mitchellh.ghostty.png";
          categories = [ "System" "TerminalEmulator" ];
          startupNotify = true;
        };
      })
    ];

    xdg.configFile = lib.mkMerge [
      (lib.optionalAttrs cfg.manage.alacritty {
        "alacritty/alacritty.toml".source = repo + "/home/config/alacritty/alacritty.toml";
        "alacritty/theme.toml" = {
          text  = alacrittyTheme;
          force = true;
        };
      })

      (lib.optionalAttrs cfg.manage.ghostty {
        "ghostty/config" = {
          source = repo + "/home/config/ghostty/config";
          force  = true;
        };
        # ghostty/theme is intentionally NOT managed by nix.
        # set-theme.sh owns it so ghostty can detect changes via inotify.
      })

      (lib.optionalAttrs cfg.manage.nvim {
        "nvim" = {
          source    = nvimSource;
          recursive = true;
        };
        "nvim/lua/paarth/theme.lua" = {
          text  = nvimTheme;
          force = true;
        };
      })

      (lib.optionalAttrs cfg.manage.sway {
        "wofi/config".source = repo + "/home/config/wofi/config";
        "wofi/style.css" = {
          text  = wofiStyle;
          force = true;
        };

        "sway/config".source = repo + "/window-managers/sway/config";
        "sway/colors.conf" = {
          text  = swayColors;
          force = true;
        };
        "sway/outputs".source = repo + "/window-managers/sway/outputs";
        "sway/workspaces".source = repo + "/window-managers/sway/workspaces";
        "sway/scripts".source = repo + "/window-managers/sway/scripts";

        "waybar/config".source = repo + "/window-managers/sway/waybar/config";
        "waybar/quick-settings-menu.xml".source = repo + "/window-managers/sway/waybar/quick-settings-menu.xml";
        "waybar/style.css" = {
          text = waybarStyle;
          force = true;
        };
      })
    ];
  };
}

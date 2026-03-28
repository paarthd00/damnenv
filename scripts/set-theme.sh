#!/usr/bin/env bash
# Apply a theme from themes/<name>.json directly to live config paths.
# Faster than a full Home Manager rebuild — use this for switching themes
# in an active session.  Run bootstrap.sh to do a full apply with Nix.
set -euo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)"
THEMES_DIR="$ROOT_DIR/themes"

usage() {
  echo "Usage: set-theme.sh <theme>"
  echo ""
  echo "Available themes:"
  for f in "$THEMES_DIR"/*.json; do
    echo "  $(basename "$f" .json)"
  done
  exit 1
}

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required" >&2; exit 1
fi

# ── resolve theme ────────────────────────────────────────────────────────────

if [ "${1:-}" = "" ]; then
  echo "Select a theme:"
  choices=()
  i=1
  for f in "$THEMES_DIR"/*.json; do
    name="$(basename "$f" .json)"
    echo "  $i) $name"
    choices+=("$name")
    i=$((i + 1))
  done
  printf "Choice [1-%s]: " "$((i - 1))"
  read -r input
  THEME="${choices[$((input - 1))]}"
else
  THEME="$1"
fi

JSON="$THEMES_DIR/$THEME.json"
[ -f "$JSON" ] || { echo "error: unknown theme: $THEME"; usage; }

echo "Applying theme: $THEME"

# ── read JSON ────────────────────────────────────────────────────────────────

q() { jq -r "$1" "$JSON"; }

bg=$(q .background);        fg=$(q .foreground)
cursor=$(q .cursor);        cursor_text=$(q .cursor_text)
sel_bg=$(q .selection_bg);  bg2=$(q .bg2)
border=$(q .border);        fg_dim=$(q .fg_dim)
accent=$(q .accent);        lock_bg="${bg:1}"

n_black=$(q .normal.black);   n_red=$(q .normal.red)
n_green=$(q .normal.green);   n_yellow=$(q .normal.yellow)
n_blue=$(q .normal.blue);     n_magenta=$(q .normal.magenta)
n_cyan=$(q .normal.cyan);     n_white=$(q .normal.white)

b_black=$(q .bright.black);   b_red=$(q .bright.red)
b_green=$(q .bright.green);   b_yellow=$(q .bright.yellow)
b_blue=$(q .bright.blue);     b_magenta=$(q .bright.magenta)
b_cyan=$(q .bright.cyan);     b_white=$(q .bright.white)

x_current=$(q .xmonad.current); x_visible=$(q .xmonad.visible)
x_hidden=$(q .xmonad.hidden);   x_hnw=$(q .xmonad.hidden_no_win)
x_title=$(q .xmonad.title);     x_layout=$(q .xmonad.layout)

nvim_cs=$(q .nvim.colorscheme); nvim_trans=$(q .nvim.transparent)

hex_to_rgb() {
  local hex="${1:1}"
  printf "%d, %d, %d" "$((16#${hex:0:2}))" "$((16#${hex:2:2}))" "$((16#${hex:4:2}))"
}
bg_rgb=$(hex_to_rgb "$bg")

# ── write helper (removes nix store symlinks before writing) ─────────────────

write_file() {
  local dest="$1"
  mkdir -p "$(dirname "$dest")"
  rm -f "$dest"
  cat > "$dest"
}

# ── alacritty ────────────────────────────────────────────────────────────────

write_file ~/.config/alacritty/theme.toml << EOF
[colors.primary]
background = "$bg"
foreground = "$fg"

[colors.cursor]
text   = "$cursor_text"
cursor = "$cursor"

[colors.selection]
background = "$sel_bg"

[colors.normal]
black   = "$n_black"
red     = "$n_red"
green   = "$n_green"
yellow  = "$n_yellow"
blue    = "$n_blue"
magenta = "$n_magenta"
cyan    = "$n_cyan"
white   = "$n_white"

[colors.bright]
black   = "$b_black"
red     = "$b_red"
green   = "$b_green"
yellow  = "$b_yellow"
blue    = "$b_blue"
magenta = "$b_magenta"
cyan    = "$b_cyan"
white   = "$b_white"
EOF
echo "  wrote: ~/.config/alacritty/theme.toml"

# ── ghostty ──────────────────────────────────────────────────────────────────
# Write in-place (keep inode) so inotify triggers a live reload.
# Only break the symlink if a nix store symlink is still present.

mkdir -p ~/.config/ghostty
[ -L ~/.config/ghostty/theme ] && rm -f ~/.config/ghostty/theme
cat > ~/.config/ghostty/theme << EOF
background = $bg
foreground = $fg
cursor-color = $cursor
selection-background = $sel_bg
palette = 0=$n_black
palette = 1=$n_red
palette = 2=$n_green
palette = 3=$n_yellow
palette = 4=$n_blue
palette = 5=$n_magenta
palette = 6=$n_cyan
palette = 7=$n_white
palette = 8=$b_black
palette = 9=$b_red
palette = 10=$b_green
palette = 11=$b_yellow
palette = 12=$b_blue
palette = 13=$b_magenta
palette = 14=$b_cyan
palette = 15=$b_white
EOF
echo "  wrote: ~/.config/ghostty/theme"

# ── sway ─────────────────────────────────────────────────────────────────────

write_file ~/.config/sway/colors.conf << EOF
set \$bg      $bg
set \$bg2     $bg2
set \$border  $border
set \$fg      $fg
set \$fg_dim  $fg_dim
set \$accent  $accent
set \$lock_bg $lock_bg
EOF
echo "  wrote: ~/.config/sway/colors.conf"

# ── waybar ───────────────────────────────────────────────────────────────────

{
  cat << EOF
@define-color bg     $bg;
@define-color bg_bar rgba($bg_rgb, 0.95);
@define-color bg2    $bg2;
@define-color border $border;
@define-color fg     $fg;
@define-color fg_dim $fg_dim;

EOF
  cat "$ROOT_DIR/window-managers/sway/waybar/style-base.css"
} | write_file ~/.config/waybar/style.css
echo "  wrote: ~/.config/waybar/style.css"

# ── wofi ─────────────────────────────────────────────────────────────────────

{
  cat << EOF
@define-color bg     $bg;
@define-color bg2    $bg2;
@define-color border $border;
@define-color fg     $fg;
@define-color fg_dim $fg_dim;

EOF
  cat "$ROOT_DIR/home/config/wofi/style-base.css"
} | write_file ~/.config/wofi/style.css
echo "  wrote: ~/.config/wofi/style.css"

# ── tmux ─────────────────────────────────────────────────────────────────────

write_file ~/.tmux-theme.conf << EOF
set -g status-style                "fg=$fg,bg=$bg"
set -g message-style               "fg=$bg,bg=$n_blue"
set -g message-command-style       "fg=$bg,bg=$n_magenta"
set -g mode-style                  "fg=$bg,bg=$n_yellow"
set -g clock-mode-colour           "$n_blue"

set -g pane-border-style           "fg=$b_black"
set -g pane-active-border-style    "fg=$n_blue"

set -g window-status-style         "fg=$fg_dim,bg=$bg"
set -g window-status-current-style "fg=$bg,bg=$n_blue,bold"
set -g window-status-activity-style "fg=$n_green,bg=$bg,bold"
set -g window-status-bell-style    "fg=$bg,bg=$n_red,bold"

set -g status-left-length  32
set -g status-right-length 64
set -g status-left-style   "fg=$bg,bg=$n_blue,bold"
set -g status-left         "#S "
set -g status-right-style  "fg=$bg,bg=$n_magenta,bold"
set -g status-right        "%Y-%m-%d %H:%M "
EOF
echo "  wrote: ~/.tmux-theme.conf"

# ── nvim ─────────────────────────────────────────────────────────────────────

write_file ~/.config/nvim/lua/paarth/theme.lua << EOF
return {
  colorscheme = '$nvim_cs',
  transparent = $nvim_trans,
}
EOF
echo "  wrote: ~/.config/nvim/lua/paarth/theme.lua"

# ── xmobarrc ─────────────────────────────────────────────────────────────────

write_file ~/xmobarrc << EOF
Config
  { font     = "xft:Fira Code:size=11:antialias=true"
  , bgColor  = "$bg"
  , fgColor  = "$fg"
  , position = TopSize L 100 26
  , border   = NoBorder
  , commands =
      [ Run UnsafeXPropertyLog "_XMONAD_LOG"
      , Run Com "sh"
          [ "-c"
          , "cap=\$(cat /sys/class/power_supply/BAT0/capacity); status=\$(cat /sys/class/power_supply/BAT0/status); if [ \"\$status\" = \"Charging\" ] || [ \"\$status\" = \"Full\" ]; then echo \"AC \${cap}%\"; else echo \"BAT \${cap}%\"; fi"
          ] "battery" 50
      , Run Date "<fc=$x_current>%a %d %b</fc>  <fc=$n_magenta>%H:%M</fc>" "date" 50
      ]
  , template = "  %_XMONAD_LOG%  }{ %battery%  %date%  "
  }
EOF
echo "  wrote: ~/xmobarrc"

# ── xmonad ───────────────────────────────────────────────────────────────────

write_file ~/.xmonad/lib/Colors.hs << EOF
module Colors where

colorBg, colorFg :: String
colorBg          = "$bg"
colorFg          = "$fg"

colorCurrent, colorVisible, colorHidden, colorHiddenNoWin :: String
colorCurrent     = "$x_current"
colorVisible     = "$x_visible"
colorHidden      = "$x_hidden"
colorHiddenNoWin = "$x_hnw"

colorTitle, colorLayout :: String
colorTitle       = "$x_title"
colorLayout      = "$x_layout"

colorDate, colorTime :: String
colorDate        = "$x_current"
colorTime        = "$n_magenta"
EOF
echo "  wrote: ~/.xmonad/lib/Colors.hs"

# ── reload live apps ─────────────────────────────────────────────────────────

echo ""
echo "Reloading..."

if command -v swaymsg >/dev/null 2>&1 && swaymsg -t get_version >/dev/null 2>&1; then
  swaymsg reload >/dev/null 2>&1 && echo "  reloaded: sway" || echo "  warn: sway reload failed"
fi

if command -v tmux >/dev/null 2>&1 && tmux info >/dev/null 2>&1; then
  tmux source-file ~/.tmux-theme.conf \; refresh-client -S >/dev/null 2>&1 \
    && echo "  reloaded: tmux" || echo "  warn: tmux reload failed"
fi

if command -v xmonad >/dev/null 2>&1 && pgrep -x xmonad >/dev/null 2>&1; then
  xmonad --recompile >/dev/null 2>&1 \
    && xmonad --restart >/dev/null 2>&1 \
    && echo "  reloaded: xmonad" || echo "  warn: xmonad reload failed"
fi

if [ -f ~/.config/alacritty/alacritty.toml ]; then
  touch ~/.config/alacritty/alacritty.toml ~/.config/alacritty/theme.toml 2>/dev/null || true
  echo "  nudged: alacritty"
fi

if pgrep -x ghostty >/dev/null 2>&1; then
  echo "  reloaded: ghostty"
fi

echo ""
echo "Theme applied: $THEME"

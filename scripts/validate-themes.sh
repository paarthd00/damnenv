#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)"
THEMES_DIR="$ROOT_DIR/themes"
required_files='alacritty.toml ghostty.conf nvim-theme.lua sway-colors.conf tmux.conf waybar-colors.css wofi-colors.css xmobarrc xmonad-colors.hs'
status=0

extract_alacritty_color() {
  file="$1"
  key="$2"
  awk -F'"' -v key="$key" '
    $0 ~ "\\[colors.primary\\]" { in_primary = 1; next }
    in_primary && $0 ~ /^\[/ { in_primary = 0 }
    in_primary && $0 ~ key" = " { print $2; exit }
  ' "$file"
}

extract_ghostty_color() {
  file="$1"
  key="$2"
  awk -F'= ' -v key="$key" '$1 == key { print $2; exit }' "$file"
}

for theme_dir in "$THEMES_DIR"/*; do
  [ -d "$theme_dir" ] || continue
  theme_name="$(basename "$theme_dir")"

  for rel in $required_files; do
    if [ ! -f "$theme_dir/$rel" ]; then
      printf 'missing: %s/%s\n' "$theme_name" "$rel"
      status=1
    fi
  done

  if [ -f "$theme_dir/alacritty.toml" ] && [ -f "$theme_dir/ghostty.conf" ]; then
    a_bg="$(extract_alacritty_color "$theme_dir/alacritty.toml" background)"
    a_fg="$(extract_alacritty_color "$theme_dir/alacritty.toml" foreground)"
    g_bg="$(extract_ghostty_color "$theme_dir/ghostty.conf" background)"
    g_fg="$(extract_ghostty_color "$theme_dir/ghostty.conf" foreground)"

    if [ -n "${a_bg:-}" ] && [ -n "${g_bg:-}" ] && [ "#${a_bg#\#}" != "${g_bg}" ]; then
      printf 'mismatch: %s background alacritty=%s ghostty=%s\n' "$theme_name" "$a_bg" "$g_bg"
      status=1
    fi

    if [ -n "${a_fg:-}" ] && [ -n "${g_fg:-}" ] && [ "#${a_fg#\#}" != "${g_fg}" ]; then
      printf 'mismatch: %s foreground alacritty=%s ghostty=%s\n' "$theme_name" "$a_fg" "$g_fg"
      status=1
    fi
  fi
done

if [ "$status" -eq 0 ]; then
  printf 'All theme assets validated.\n'
fi

exit "$status"

#!/usr/bin/env sh
# Validates that all theme JSON files are well-formed and have required fields.
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)"
THEMES_DIR="$ROOT_DIR/themes"
status=0

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required" >&2; exit 1
fi

required_fields='
  .background .foreground .cursor .cursor_text .selection_bg
  .bg2 .border .fg_dim .accent
  .normal.black .normal.red .normal.green .normal.yellow
  .normal.blue .normal.magenta .normal.cyan .normal.white
  .bright.black .bright.red .bright.green .bright.yellow
  .bright.blue .bright.magenta .bright.cyan .bright.white
  .xmonad.current .xmonad.visible .xmonad.hidden .xmonad.hidden_no_win
  .xmonad.title .xmonad.layout
  .nvim.colorscheme .nvim.transparent
'

for json in "$THEMES_DIR"/*.json; do
  name="$(basename "$json" .json)"

  if ! jq empty "$json" 2>/dev/null; then
    printf 'invalid json: %s\n' "$name"
    status=1
    continue
  fi

  for field in $required_fields; do
    val="$(jq -r "$field" "$json")"
    if [ "$val" = "null" ] || [ -z "$val" ]; then
      printf 'missing field %s in %s\n' "$field" "$name"
      status=1
    fi
  done
done

[ "$status" -eq 0 ] && printf 'All theme assets validated.\n'
exit "$status"

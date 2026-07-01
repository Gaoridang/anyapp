#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICON_SET="$ROOT/anyapp/Assets.xcassets/AppIcon.appiconset"

python3 "$ROOT/scripts/generate_app_icons.py"

required=(
  AppIcon-120.png
  AppIcon-152.png
  AppIcon-1024.png
)

for icon in "${required[@]}"; do
  path="$ICON_SET/$icon"
  if [[ ! -f "$path" ]]; then
    echo "Missing icon: $path" >&2
    exit 1
  fi
  file_type="$(file -b "$path")"
  if [[ "$file_type" != *"PNG image data"* ]]; then
    echo "Not a PNG: $path ($file_type)" >&2
    exit 1
  fi
done

if ! grep -q '"filename"' "$ICON_SET/Contents.json"; then
  echo "AppIcon Contents.json has no filenames." >&2
  exit 1
fi

echo "App icon tests passed."
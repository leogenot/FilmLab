#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 2 ]]; then
  printf 'Usage: %s /path/to/FilmLab.app /path/to/FilmLab.dmg\n' "$0" >&2
  exit 2
fi

app_dir="$1"
dmg_path="$2"
if [[ ! -d "$app_dir" ]]; then
  printf 'App bundle does not exist: %s\n' "$app_dir" >&2
  exit 1
fi
codesign --verify --deep --strict "$app_dir"

mkdir -p "$(dirname "$dmg_path")"
staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/FilmLab-dmg.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
ditto "$app_dir" "$staging_dir/FilmLab.app"
ln -s /Applications "$staging_dir/Applications"
codesign --verify --deep --strict "$staging_dir/FilmLab.app"

hdiutil create \
  -volname FilmLab \
  -srcfolder "$staging_dir" \
  -fs HFS+ \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov "$dmg_path"
hdiutil verify "$dmg_path"
printf 'Built and verified %s\n' "$dmg_path"

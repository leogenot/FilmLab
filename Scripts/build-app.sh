#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
output_dir="${FILMLAB_OUTPUT_DIR:-$project_dir/Dist}"
app_dir="$output_dir/FilmLab.app"

DEVELOPER_DIR="$developer_dir" swift build -c release --package-path "$project_dir"
mkdir -p "$app_dir/Contents/MacOS"
cp "$project_dir/AppResources/Info.plist" "$app_dir/Contents/Info.plist"
cp "$project_dir/.build/release/FilmLab" "$app_dir/Contents/MacOS/FilmLab"
chmod +x "$app_dir/Contents/MacOS/FilmLab"
codesign --force --deep --sign - "$app_dir"
codesign --verify --deep --strict "$app_dir"
printf 'Built and verified %s\n' "$app_dir"

#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
output_dir="${FILMLAB_OUTPUT_DIR:-$project_dir/Dist}"
app_dir="$output_dir/FilmLab.app"

DEVELOPER_DIR="$developer_dir" swift build -c release --package-path "$project_dir"
bash "$project_dir/Scripts/build-kernels.sh" "$project_dir/.build"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$project_dir/AppResources/Info.plist" "$app_dir/Contents/Info.plist"
cp "$project_dir/.build/release/FilmLab" "$app_dir/Contents/MacOS/FilmLab"
cp "$project_dir/.build/FilmKernels.metallib" "$app_dir/Contents/Resources/FilmKernels.metallib"
chmod +x "$app_dir/Contents/MacOS/FilmLab"
codesign --force --deep --sign - "$app_dir"
codesign --verify --deep --strict "$app_dir"

if [[ "$output_dir" == "$project_dir/Dist" ]]; then
  root_app="$project_dir/FilmLab.app"
  if [[ -L "$root_app" ]]; then
    if [[ "$(readlink "$root_app")" != "Dist/FilmLab.app" ]]; then
      printf 'Refusing to replace unexpected FilmLab.app symlink: %s\n' "$root_app" >&2
      exit 1
    fi
  elif [[ -e "$root_app" ]]; then
    mkdir -p "$project_dir/.build/legacy-bundles"
    backup_dir="$(mktemp -d "$project_dir/.build/legacy-bundles/FilmLab.XXXXXX")"
    mv "$root_app" "$backup_dir/FilmLab.app"
    ln -s "Dist/FilmLab.app" "$root_app"
    printf 'Preserved the old root app at %s\n' "$backup_dir/FilmLab.app"
  else
    ln -s "Dist/FilmLab.app" "$root_app"
  fi
  codesign --verify --deep --strict "$root_app"
fi

printf 'Built and verified %s\n' "$app_dir"

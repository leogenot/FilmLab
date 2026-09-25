#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
output_dir="${1:-$project_dir/.build}"
mkdir -p "$output_dir"

metal_source="$output_dir/FilmKernels.metal"
air_file="$output_dir/FilmKernels.air"
library_file="$output_dir/FilmKernels.metallib"
awk '
  /private static let source = #"""/ { capture = 1; next }
  capture && /"""#/ { exit }
  capture { print }
' "$project_dir/Sources/FilmLab/FilmKernels.swift" > "$metal_source"
if [[ ! -s "$metal_source" ]]; then
  echo "Could not extract FilmLab Metal kernels." >&2
  exit 1
fi

DEVELOPER_DIR="$developer_dir" xcrun metal -fcikernel -c "$metal_source" -o "$air_file"
# Stitchable Core Image functions need the normal Metal link mode.
DEVELOPER_DIR="$developer_dir" xcrun metallib "$air_file" -o "$library_file"
printf 'Built %s\n' "$library_file"

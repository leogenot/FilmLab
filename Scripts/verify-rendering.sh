#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
mkdir -p "$project_dir/.build"
DEVELOPER_DIR="$developer_dir" swiftc \
  "$project_dir/Sources/FilmLab/FilmKernels.swift" \
  "$project_dir/Sources/FilmLab/ColorMixer.swift" \
  "$project_dir/Tests/RenderingProbe.swift" \
  -o "$project_dir/.build/FilmLabRenderingProbe"
"$project_dir/.build/FilmLabRenderingProbe"
DEVELOPER_DIR="$developer_dir" swiftc \
  "$project_dir/Sources/FilmLab/Framing.swift" \
  "$project_dir/Tests/FramingProbe.swift" \
  -o "$project_dir/.build/FilmLabFramingProbe"
"$project_dir/.build/FilmLabFramingProbe"

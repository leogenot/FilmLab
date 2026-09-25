#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
mkdir -p "$project_dir/.build"
bash "$project_dir/Scripts/build-kernels.sh" "$project_dir/.build"
DEVELOPER_DIR="$developer_dir" swiftc \
  "$project_dir/Sources/FilmLab/FilmKernels.swift" \
  "$project_dir/Sources/FilmLab/ColorMixer.swift" \
  "$project_dir/Tests/RenderingProbe.swift" \
  -o "$project_dir/.build/FilmLabRenderingProbe"
"$project_dir/.build/FilmLabRenderingProbe"
DEVELOPER_DIR="$developer_dir" swiftc \
  "$project_dir/Sources/FilmLab/Framing.swift" \
  "$project_dir/Sources/FilmLab/FreeCrop.swift" \
  "$project_dir/Tests/FramingProbe.swift" \
  -o "$project_dir/.build/FilmLabFramingProbe"
"$project_dir/.build/FilmLabFramingProbe"
DEVELOPER_DIR="$developer_dir" swiftc \
  "$project_dir/Sources/FilmLab/FilmKernels.swift" \
  "$project_dir/Sources/FilmLab/FilmEffects.swift" \
  "$project_dir/Tests/TextureProbe.swift" \
  -o "$project_dir/.build/FilmLabTextureProbe"
"$project_dir/.build/FilmLabTextureProbe"
DEVELOPER_DIR="$developer_dir" swiftc \
  "$project_dir/Sources/FilmLab/LocalExposure.swift" \
  "$project_dir/Sources/FilmLab/RadialAdjustment.swift" \
  "$project_dir/Tests/LocalExposureProbe.swift" \
  -o "$project_dir/.build/FilmLabLocalExposureProbe"
"$project_dir/.build/FilmLabLocalExposureProbe"
DEVELOPER_DIR="$developer_dir" swiftc \
  "$project_dir/Sources/FilmLab/ImageExporter.swift" \
  "$project_dir/Tests/ExporterProbe.swift" \
  -o "$project_dir/.build/FilmLabExporterProbe"
"$project_dir/.build/FilmLabExporterProbe"
DEVELOPER_DIR="$developer_dir" swiftc \
  "$project_dir/Sources/FilmLab/ImageDecoder.swift" \
  "$project_dir/Tests/ImageDecoderProbe.swift" \
  -o "$project_dir/.build/FilmLabImageDecoderProbe"
"$project_dir/.build/FilmLabImageDecoderProbe"
DEVELOPER_DIR="$developer_dir" swiftc \
  "$project_dir/Sources/FilmLab/FilmKernels.swift" \
  "$project_dir/Sources/FilmLab/PreviewRenderer.swift" \
  "$project_dir/Tests/PreviewRendererProbe.swift" \
  -o "$project_dir/.build/FilmLabPreviewRendererProbe"
"$project_dir/.build/FilmLabPreviewRendererProbe"
DEVELOPER_DIR="$developer_dir" swiftc \
  "$project_dir/Sources/FilmLab/SavedEditStore.swift" \
  "$project_dir/Tests/SavedEditStoreProbe.swift" \
  -o "$project_dir/.build/FilmLabSavedEditStoreProbe"
"$project_dir/.build/FilmLabSavedEditStoreProbe"
DEVELOPER_DIR="$developer_dir" swiftc \
  "$project_dir/Sources/FilmLab/EditRecordLocator.swift" \
  "$project_dir/Tests/EditRecordLocatorProbe.swift" \
  -o "$project_dir/.build/FilmLabEditRecordLocatorProbe"
"$project_dir/.build/FilmLabEditRecordLocatorProbe"
DEVELOPER_DIR="$developer_dir" swiftc \
  "$project_dir/Sources/FilmLab/LookFile.swift" \
  "$project_dir/Tests/LookFileProbe.swift" \
  -o "$project_dir/.build/FilmLabLookFileProbe"
"$project_dir/.build/FilmLabLookFileProbe"

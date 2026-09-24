# FilmLab

A small native macOS photo editor focused on film rendering and color grading.

## Current prototype

- Opens JPEG and RAW formats supported by the Mac's Core Image decoder. Verified with a Sony ILCE-7M4 ARW at 4672 × 7008 pixels.
- Provides exposure correction, contrast, saturation, warmth, plus Shot Exposure, Development and Amount for an exposure-dependent film response.
- Adds shadow, midtone, and highlight color timing, plus content-dependent grain and highlight-edge halation. These controls default to off.
- Saves non-destructive edits per source file in `~/Library/Application Support/FilmLab/Edits/` and restores them on reopening.
- Includes Before/After, Reset Edits, and a scrollable 100% source-pixel inspection mode.
- Previews edits in sRGB and exports a full-resolution sRGB JPEG or 16-bit Display P3 TIFF.
- Leaves the source photo unchanged.

The current film response is a provisional model in an extended linear sRGB working space. It has toe and shoulder behavior that changes with exposure and development, but it is not a measured film stock or a claim of faithful emulation.

## Run

Open `Package.swift` in Xcode and run the `FilmLab` executable target, or open `FilmLab.app` for the last verified build. When rebuilding the bundled app manually, copy `.build/debug/FilmLab` into `FilmLab.app/Contents/MacOS/` and re-sign it with `codesign --force --deep --sign - FilmLab.app`. To rebuild from Terminal, run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`.

## Next image-quality milestone

1. Verify RAW/JPEG input normalization and preview/export parity with image comparisons at several exposure values and a 100% zoom view.
2. Capture matched digital and film references across several exposures and lighting conditions for one stock.
3. Fit exposure-dependent tone and color transforms to those references.
4. Calibrate stock-dependent grain, halation, and edge response; evaluate them at 100% zoom.
5. Compare RAW and JPEG renderings of the same scenes and tune input normalization.

## Current limits

The film response and texture kernels are provisional and use Core Image’s deprecated text-kernel API. Move them to Metal before a production release. The app currently has one study stock and tonal grading, but no masks, pixel-specific color mixer, or calibrated emulsion data. The 100% view renders the full source and allows scrolling, but very large images increase memory use while inspecting. A tiled preview renderer is a future performance improvement. The TIFF exporter was verified on `LEO00403.ARW` at 4672 × 7008 and 16 bits per sample.

The editor uses a three-column dark layout: file and workspace navigation on the left, photo canvas in the center, and one focused control group on the right.

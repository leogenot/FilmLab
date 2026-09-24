# FilmLab

A small native macOS photo editor focused on film rendering and color grading.

## Current prototype

- Opens JPEG and RAW formats supported by the Mac's Core Image decoder, identifying RAW through the file's ImageIO type. Verified with a Sony ILCE-7M4 ARW at 4672 × 7008 pixels.
- Provides RAW white balance, pre-film shadow and highlight light controls, up to eight radial local light adjustments, output exposure, contrast, saturation, creative warmth, plus Shot Exposure, Development and Amount for an exposure-dependent film response. New RAW imports default to a linear decoder response with its global and shadow tone curves disabled; the decoder-rendered mode remains available. The Film workspace offers the original study stock and experimental Portra 400 and Ektar 100 density studies based on Kodak’s published negative curves. The Portra and Ektar studies have optional Portra Endura and Endura Premier paper response stages, respectively.
- Adds shadow, midtone, and highlight color timing, a hue-range selective color adjustment, and an eight-family Color Mixer with hue, saturation and luminance controls. The color controls default to off. Repeatable, luminance-weighted grain and highlight-edge halation are also available.
- Saves non-destructive edits per source file in `~/Library/Application Support/FilmLab/Edits/`, flushes them when the app leaves the foreground, and automatically reopens the last available photo on launch.
- Includes an output luminance histogram, Before/After, a draggable split comparison, non-destructive quarter-turn rotation, ±15° straighten, crop ratios with position controls and draggable freeform crop bounds, bounded Undo/Redo, Copy/Paste Settings between photos, Reset Edits, and a scrollable 100% source-pixel inspection mode.
- Renders previews asynchronously in sRGB, coalescing rapid control changes so the canvas stays responsive. Exports full-resolution sRGB JPEG or 16-bit Display P3 TIFF in a separate background renderer.
- Leaves the source photo unchanged. Copy/Paste Settings transfers the saved grade, local areas, texture and framing. The destination keeps its own RAW decoder mode, highlight recovery and camera white balance settings.

The original study stock is a provisional response model. The Portra and Ektar density studies use approximate samples from Kodak’s separate published negative-density charts, followed by a provisional balanced positive transform. Each optional paper stage blends the provisional positive with negative density mapped through approximate red, green and blue curves from Kodak’s Portra Endura or Endura Premier paper sheet. Paper Exposure controls the paper’s light exposure, and Paper Strength controls the blend; existing edits default to 0 EV and 50%. This is an exploratory paper color response rather than calibrated color-paper reproduction. The spectral and print/scan stages remain incomplete; see `CALIBRATION-PLAN.md` for the reference data needed to validate them.

Existing saved RAW edits keep their chosen decoder mode. Reset Edits returns a RAW to linear input. JPEGs remain tagged-display images converted into the extended-linear working space; lost highlight detail or an unknown camera JPEG tone curve cannot be recovered from them.

## Run

Open `Package.swift` in Xcode and run the `FilmLab` executable target. For a signed local release bundle, run `Scripts/build-app.sh` and open `Dist/FilmLab.app`. The script builds with SwiftPM in release mode, assembles the bundle, signs it ad hoc, and verifies the signature. This local build is not notarized for distribution to other Macs. The root `FilmLab.app` is a manually updated development bundle. Run `Scripts/verify-rendering.sh` to compile the Metal kernels and check neutral balance, exposure order, distinct stock response and pre-film tonal controls.

## Next image-quality milestone

1. Verify RAW/JPEG input normalization and preview/export parity with image comparisons at several exposure values and a 100% zoom view.
2. Refine the published-data density stage, then model film spectral sensitivity and a separately specified print/scan stage.
3. Validate the resulting positive output against legally usable reference scans across several exposures and lighting conditions.
4. Calibrate stock-dependent grain, halation, and edge response; evaluate them at 100% zoom.
5. Compare RAW and JPEG renderings of the same scenes and tune input normalization.

## Current limits

The film response and texture kernels are provisional. They use stitchable Metal Core Image kernels compiled at runtime on this Mac; a packaged, precompiled Metal library would improve startup and broader device support. The app has three stock choices, tonal grading and radial local adjustments, but no painted masks or fully calibrated emulsion-to-print transform. Radial areas use normalized source coordinates and can be inverted to target the surroundings. The temporary mask view follows rotation and crop, and Place on photo maps a click through rotation, straighten and crop back to the unrotated source. Position sliders remain relative to that source. The Color Mixer uses soft RGB hue ranges, not a measured film dye response. The 100% view renders the full source and allows scrolling, but very large images increase memory use while inspecting. Preview rendering uses a half-float working buffer; export uses a 32-bit float working buffer before final output conversion. A tiled preview renderer is a future performance improvement. The TIFF exporter was verified on `LEO00403.ARW` at 4672 × 7008 and 16 bits per sample.

The editor uses a three-column dark layout: file and workspace navigation on the left, photo canvas in the center, and one focused control group on the right. Framing offers Original, 1:1, 4:5, 3:2, 16:9, and freeform crops after rotation and straighten. Freeform bounds can be adjusted with sliders or dragged over the uncropped preview; export always uses the crop. Straighten crops inward to avoid empty corners, so larger angles discard more edge pixels.

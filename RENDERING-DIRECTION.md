# FilmLab rendering direction

FilmLab is a digital image editor that simulates photographic film. The film stock must respond differently to different scene exposures and colors, rather than apply one fixed color preset to already rendered pixels.

## What the current prototype does

`Sources/FilmLab/main.swift` currently decodes RAW through `CIRAWFilter`, then applies `CIExposureAdjust`, `CIColorControls`, a five-point `CIToneCurve`, and global `CITemperatureAndTint`. RAW and JPEG share this simplistic transform. This proves import, preview, and export, but does not yet provide a believable stock response. The curve operates on display-oriented 0–1 control points and does not model film density versus log exposure or channel interaction. Calling the input “16-bit” is not enough by itself: intermediate processing must preserve high-precision, extended-range values until output conversion.

## Target pipeline

1. Decode RAW with its camera profile and white balance into a high-precision, scene-referred working image. Preserve highlight and shadow latitude. Decode JPEG with its embedded color profile, while acknowledging that its tone curve and clipping are already baked in.
2. Apply exposure as a scene-light change before the film response. The same stock must produce different density, hue and saturation behavior at different exposures.
3. Map linear light to log exposure relative to an explicit middle-gray reference. Use separate, smooth response functions for the three dye layers, with toe, straight-line region, shoulder and cross-channel interactions. Keep a working range beyond display white and black.
4. Let development alter the stock response itself (contrast, density, color separation and highlight roll-off), rather than only adjusting a final contrast slider.
5. Apply spatial effects such as grain, halation and acutance using luminance, exposure and edge information. Grain and halation should vary with image content, not be uniform overlays.
6. Apply selective color timing and finishing controls; convert to the chosen output color space at the end. Preview and export must use the same rendering graph and differ only in resolution/output encoding.

## First implementation milestone

Replace the provisional five-point curve with one documented, tunable film-response model implemented in a high-precision Core Image kernel or Metal shader. Add a `Shot Exposure` control *before* that model and a `Development` control that changes its shape. Make a repeatable comparison grid of the same RAW at -2, 0 and +2 EV, plus a JPEG of the same scene. Inspect highlight hue, skin and foliage separation, shadow density and clipping, rather than judging only a single final image. Do not claim measured-stock accuracy until a calibration target and reference exposures exist.

## Key distinction from the Chromogen trial

Chromogen's UI, output and saved edit fields suggest exposure-dependent stock behavior, and its site describes measured density across stops. The trial does not disclose the exact equations, processing order, source measurements or shaders. FilmLab can build its own physically motivated response without copying its implementation or branding.

## First comparison, 24 September 2026

Rendered `LEO00403.ARW` through the provisional response at Shot Exposure -2, 0 and +2 EV. The first toe setting lifted low-exposure blacks to an obvious gray floor. Moving the toe transition from -2 to -4.5 stops kept dark rock and clothing dark while preserving visible texture. The +2 frame retains more rock detail than a simple global brightness increase, though the bright sky still approaches display white. Three 1100-pixel review JPEGs are in `Comparisons/`. These are visual regression references, not calibrated film matches.

## Editor workflow added, 24 September 2026

Per-photo edits now save in Application Support and restore after an app restart. Before/After and Reset Edits work in the running app. Preview uses explicit sRGB conversion, matching JPEG export's output color space. A full-resolution Display P3 TIFF export was verified at 16 bits per sample. Provisional grain varies with output luminance; provisional halation uses blurred bright-region spill around highlight edges. Both default to off. At 50% settings, a full-resolution crop showed a subtle texture difference without broad color drift. Precise film-like texture remains uncalibrated and needs 100% in-app inspection.

## Tonal color timing added, 24 September 2026

Shadow, midtone and highlight hue/strength controls now apply after the film response and before spatial effects. Their masks depend on output luminance with smooth overlap. In the app, a strong blue shadow grade changed dark rock and clothing while leaving bright sky largely unchanged; a warm highlight grade changed brighter parts. They are optional and default to zero. This is tonal grading, not object-aware selection or a full color mixer. The test edits were reset afterward.

## Full-resolution inspection and focused editor, 24 September 2026

The app now has a Fit/100% switch. At 100%, it renders the full-resolution image and presents a scrollable pixel-level view for checking grain, edges and halation. The editing UI now uses a restrained dark three-column layout with Film, Develop, Color and Texture workspaces; only the active workspace's controls occupy the inspector. The RAW sample opened and rendered correctly in this layout.

## Responsive rendering and export, 24 September 2026

Preview rendering now runs in a separate actor with a 16-bit half-float extended linear sRGB working buffer. Rapid control changes are debounced and older results are discarded. Full-resolution JPEG and 16-bit Display P3 TIFF exports run in a separate actor with a 32-bit float working buffer, so export does not freeze the editor. Each background job retains access to its source file until it completes. A Sony ARW export was verified at 4672 × 7008 pixels and 16 bits per sample. This verifies the output container and working format, not a measured film response or guaranteed recovery of source detail.

## Selective color, 24 September 2026

The Color workspace now includes target hue, color range, hue shift and saturation. A smooth hue and chroma mask chooses pixels after tonal grading and before texture effects; the hue rotation preserves an approximate luma value. The same graph feeds preview and export. A strong warm-color shift visibly changed the red hat and warm rock on the Sony RAW while leaving much of the blue sky alone; the test edit was reset. This is a broad color-range tool, not an object mask or measured film dye response.

## Metal kernel migration, 24 September 2026

The response, tonal grade, selective color, grain, highlight mask and halation kernels now use stitchable Metal functions loaded through Core Image. All six compiled and rendered on this Mac in a small synthetic-image probe. The signed app also reopened the Sony RAW and rendered active grain and halation controls without an error; the test edits were reset. Runtime Metal compilation is appropriate for this Swift package prototype, though a future Xcode app target should bundle a precompiled Metal library. This migration preserves the provisional response equations; it does not calibrate them.

## Split comparison, 24 September 2026

The canvas now offers a draggable Before/After split at Fit zoom. Both sides are rendered from the same source image with the same explicit sRGB preview conversion; the edited side uses the full current film graph. The split was visually checked on the Sony RAW, then dragged across the image. It makes exposure and color changes easier to judge spatially without changing the export graph.

## RAW decoder tone modes, 24 September 2026

On `LEO00403.ARW`, Core Image initialized global boost to 1.0 and shadow boost to 0.9. FilmLab now exposes a per-photo Flat RAW input switch in Develop. It sets those two boosts and local tone mapping to zero before the stock response; the default mode preserves the earlier Apple decoder rendering for existing edits. Two temporary sRGB previews showed a flatter, darker lower half and a less cyan sky from the flat decode. The in-app switch visibly changed the RAW preview, and its saved state restored after reopening the file. Flat does not imply untouched sensor data: camera profiling, white balance, demosaicing and baseline exposure still occur.

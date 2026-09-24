# FilmLab rendering direction

FilmLab is a digital image editor that simulates photographic film. The film stock must respond differently to different scene exposures and colors, rather than apply one fixed color preset to already rendered pixels.

## What the current prototype does

`Sources/FilmLab/main.swift` decodes RAW through `CIRAWFilter` and JPEG through Core Image, then applies the provisional exposure-dependent stock response and finishing controls. RAW decoder settings, including white balance, act before the stock. Shot Exposure changes the stock's log-light input; Output Exposure, contrast, saturation, warmth and color timing act after it. Preview and export use extended-linear sRGB working spaces with half-float and float precision respectively, then convert to their output profiles. The stock response is still a study model rather than a measured emulsion profile.

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

## Output histogram, 24 September 2026

The inspector now displays a 64-bin luminance histogram of a downsampled sRGB render of the current image. Near-black and near-white percentages count pixels within roughly the outer four 8-bit luminance levels. The histogram updates with the preview and is calculated outside the UI actor. On the Sony RAW, increasing Shot Exposure to +2.56 EV moved the plot to the right and raised near-white coverage to 24.1%; the edit was reset. These are display-output diagnostics, not a measurement of clipped sensor values or available RAW headroom.

## RAW white balance, 24 September 2026

Develop now shows the RAW decoder’s camera temperature and tint as editable, per-photo values. These change `CIRAWFilter` before the film response, while the existing Warmth slider remains a later creative color adjustment. The Sony RAW opened at 5634 K and tint 4.0; moving temperature to roughly 9236 K visibly warmed the scene, then increasing tint to roughly 36.6 shifted it toward magenta. The histogram changed with the render, and Reset Edits restored the camera defaults. JPEGs do not show these RAW controls.

## RAW control responsiveness, 24 September 2026

RAW decoder changes are coalesced for 90 milliseconds before rebuilding the source image. This prevents each intermediate slider value from triggering its own decode. The first revision cancelled the initial preview while restoring camera defaults; that cancellation ordering was corrected. Reopening the Sony RAW now shows the image and histogram, and three rapid temperature changes resolve to the final 7407 K preview. The test edit was reset.

## Preview/export parity and stock strength, 24 September 2026

A direct RAW render probe compared the current half-float preview context with the float export context at -2, 0 and +2 EV. Every output channel differed by at most one 8-bit level at a 1000-pixel preview size. A separate full-resolution JPEG round-trip differed from a direct preview by a mean of 0.40 levels at 0 EV and 0.54 at +2 EV; the 95th percentile was one and two levels respectively. JPEG compression and resizing account for the remaining difference. These probes cover the stock response, not every optional grading and texture combination.

The prior default Stock amount of 0.7 mixed 30% linear exposure back into the shoulder. At +2 EV, the RAW comparison showed visibly harsher rock highlights and more blown white than full stock strength. New photos and Reset Edits now default to 1.0; stored edits with an explicit amount remain unchanged. This improves the film response’s control of highlights, though the provisional stock still needs measured calibration.

## JPEG export quality, 24 September 2026

JPEG export now explicitly requests 0.95 lossy compression quality. A full-resolution Sony RAW render with visible grain measured 8.3 MB at Core Image’s default quality and 13.2 MB at 0.95. The higher-quality default preserves more fine texture for the editor’s primary delivery format, at the cost of larger files. TIFF remains the lossless high-bit-depth option.

## Image type detection, 24 September 2026

RAW import now uses ImageIO’s detected type and `UTType.rawImage` conformance instead of a short file-extension list. This matters because `CIRAWFilter(imageURL:)` also accepted the JPEG test file, so a non-nil filter was not a reliable RAW check. The Sony ARW was detected as `com.sony.arw-raw-image`, and the JPEG as `public.jpeg`. In the packaged app, the JPEG opened without RAW controls, while the ARW reopened with them. A full-resolution JPEG exported through the app at 4672 × 7008 with an embedded sRGB profile.

## Input-specific stock defaults, 24 September 2026

New RAW imports start at 1.0 Stock amount, while new JPEG imports start at 0.7. Reset Edits uses the same input-specific defaults. This reflects their different starting points: the JPEG has a camera or software tone rendering baked in, while the RAW decoder can supply a flatter working image. Explicitly saved stock amounts are still restored as chosen. These are starting values, not calibrated stock measurements.

### RAW highlight recovery

When macOS reports support for highlight recovery in a RAW file, Develop exposes the decoder's Highlight recovery switch. It defaults on, as the decoder does. The choice is saved per image and changing it re-decodes the RAW before the film response. The control is hidden for JPEGs and for RAW decoders that do not support it. This can reconstruct detail only when the camera data contains enough unclipped color-channel information; it cannot recover fully saturated sensor values.

## Exposure stages, 24 September 2026

The old Develop Exposure correction, contrast and saturation controls ran before the film response. This made Exposure correction overlap with Shot Exposure. They now run after the stock response, and the slider is named Output exposure (EV). On a neutral linear-light test patch, +2 Shot Exposure produced approximately 0.52–0.56 per channel after the stock shoulder, while +2 Output Exposure produced approximately 0.83–0.84. The same stage order feeds preview and export. Previously saved nonzero Develop exposure, contrast or saturation edits may look different after this rendering change; their numeric settings are preserved.

## Published-density Portra study, 24 September 2026

The Film stock picker now offers an experimental Portra 400 density study alongside the original stock. `Research/portra400-density.csv` contains nine graph-read samples of Kodak E-4050's Status M negative-density curves. A Metal kernel maps per-channel linear-light exposure to log H relative to an assumed 0.18-to--1.44 anchor, interpolates the three measured curves, and applies a provisional Development slope around the anchor. A second Metal kernel maps balanced negative density into a positive output using a provisional print/scan contrast and display shoulder. The two stages remain separate so the published negative measurements are not confused with our output rendering assumptions. Beyond the plotted range, the negative stage holds its low-density end and extrapolates the last high-density slope; neither extension is measured.

The Metal probe compiled and rendered both kernels. An explicitly linear 0.18 gray patch produced red/green/blue densities of approximately 0.891/1.365/1.765 at the anchor and a neutral 0.18 positive. At -2 and +2 Shot Exposure it produced positive RGB values of roughly 0.072/0.068/0.059 and 0.396/0.402/0.443. In the packaged app, the Sony RAW rendered under both stocks and at +2 EV. The Portra study looked flatter and brighter in shadows than the original stock at zero EV. Its selection and exposure value restored after reopening, Reset Edits restored the old stock, and a full-resolution 4672 × 7008 sRGB JPEG exported successfully. The user's original RAW was never modified; the app tests used a copy in `/private/tmp`.

## Spectral-layer overlap approximation, 24 September 2026

The Portra density study now mixes a small amount of neighboring linear-RGB channels into each virtual film-sensitive layer before evaluating the manufacturer-derived density curves. The matrix is recorded in `FILM-STOCK-SOURCES.md` and preserves neutral input. It is an RGB approximation of the overlaps visible in Kodak's spectral plot, not a recovered scene spectrum or a measured film sensitivity matrix. A synthetic linear-light probe kept 0.18 gray neutral; warm, sky-blue and foliage patches remained in their hue families with softer saturation. The signed app rendered the Sony RAW with the updated stock, and its test edit was reset. On a 1000-pixel RAW rendering at -2, 0 and +2 EV, half-float preview and float export contexts differed by at most one 8-bit channel level (mean differences 0.007, 0.010 and 0.015 levels respectively).
## Optional paper response study

The Portra density stock can route its processed negative through approximate Kodak Portra Endura paper characteristic curves. The data is digitized from Kodak E-4021's red, green and blue Status A density curves; `Research/endura-paper-tone.csv` and `FILM-STOCK-SOURCES.md` record the graph readings and assumptions. Negative density reduces relative enlarger exposure; each sampled paper curve maps that exposure to paper density; relative reflectance is `10^-density`. A neutral enlarger balance and 0.75-density mid-gray aim are assumed. Paper Exposure shifts log paper exposure by EV × log10(2); increasing it makes the print darker. Paper Strength blends the response with the provisional positive and defaults to 0.5 because the full curve crushed shadows on the Sony test frame. This is an exploratory paper color response, not a calibrated color-paper or optical-print model.

The three-curve probe kept the 0 EV neutral patch at approximately 0.179 in each channel, and paper exposure at -2/0/+2 EV produced approximately 0.441/0.179/0.092 output at the default 50% blend. Differences between the paper channels remain small for this patch because the published curves overlap through most of the exposure range. The updated app rendered the Sony RAW and exported a 4672 × 7008 sRGB JPEG with the paper response enabled.

## Smooth density interpolation

Both the Portra negative and Endura paper lookups now use shape-preserving cubic Hermite joins instead of straight lines between the graph readings. The per-channel PCHIP tangents are calculated from the checked-in CSV samples. A dense check of 100 positions per interval and channel found every interpolated value monotonic and inside its two endpoint densities. The Metal render probe kept 0.18 reference gray neutral, and the Sony RAW rendered and exported as a 4672 × 7008 sRGB JPEG in the signed app. The smoothing does not imply that Kodak measured intermediate points.

## RAW input normalization

Apple's CIRAWFilter defaults to a global tone curve (`boostAmount = 1`), and the Sony test RAW reported a shadow boost of 0.9. New RAW imports now use zero global, shadow, and local tone-map boosts so the film stages receive the decoder's linear response. The setting remains reversible, and saved edits keep their previous value. A 300 × 450 float working-space probe of the Sony file measured median linear luminance of about 0.095 with these boosts off versus 0.182 with defaults; both versions retained sample channels above 1.0. The available JPEG, which may already be camera or app rendered, measured about 0.305 median, so it is not a reliable reference for matching the RAW's input exposure. A fresh RAW and JPEG copy both opened in the app; Reset Edits retained the new RAW default and the JPEG kept its 0.7 stock amount. The linear RAW path exported successfully to a full-resolution 4672 × 7008 sRGB JPEG.

## Published-density Ektar study, 24 September 2026

The Film stock picker now includes an Ektar 100 density study from Kodak E-4046's daylight Status M negative-density chart. `Research/ektar100-density.csv` records nine graph-read samples per channel and `FILM-STOCK-SOURCES.md` describes their digitization. The Metal negative stage selects Ektar's PCHIP curves and a 0.18-gray-to--0.84-log-H anchor, while the positive stage uses the same provisional balancing and print/scan response as Portra. The neutral-preserving RGB layer matrix, development behavior and positive output are assumptions; distinct measured density curves alone do not establish an accurate Ektar color look. The Portra Endura paper option is available only for the Portra study.

A Metal render probe checked both stocks at -2, 0 and +2 Shot Exposure. Both mapped neutral 0.18 scene light to neutral 0.18 output at zero exposure. At -2/+2, Portra produced approximately `[0.071, 0.068, 0.059]` / `[0.396, 0.402, 0.443]`; Ektar produced `[0.064, 0.064, 0.056]` / `[0.411, 0.412, 0.462]`. A dense check of 100 positions per Ektar curve segment found monotonic, endpoint-bounded interpolation. The signed app rendered Ektar on a test copy of the Sony RAW and a JPEG. Reopening the RAW restored the selected stock and +1.98 EV test exposure; the test exposure was then returned to zero. The RAW exported a 4672 × 7008 sRGB JPEG at +2 EV. These checks show a functioning, exposure-dependent implementation, not reference-film matching.

## Non-destructive framing, 24 September 2026

Rotation by quarter turns and centered crop ratios now run after grading and texture. The framing state is saved per photo, and a normalized horizontal/vertical crop position chooses the visible region without changing the source file. The same Core Image geometry is used for preview, Before/After, 100% inspection and export. A JPEG test crop rotated right and set to 1:1 rendered in the app; split comparison stayed aligned, and the full-resolution export measured 4672 × 4672 pixels. The JPEG's saved edit file recorded both the rotation and ratio. Freeform and straighten-angle cropping remain future work.

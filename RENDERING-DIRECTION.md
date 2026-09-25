# FilmLab rendering direction

FilmLab is a digital image editor that simulates photographic film. The film stock must respond differently to different scene exposures and colors, rather than apply one fixed color preset to already rendered pixels.

## What the current prototype does

`Sources/FilmLab/main.swift` decodes RAW through `CIRAWFilter` and JPEG through Core Image, then applies the provisional exposure-dependent stock response and finishing controls. RAW decoder settings, including white balance, act before the stock. Shot Exposure changes the stock's log-light input; Output Exposure, contrast, saturation, warmth and color timing act after it. Preview uses an extended-linear sRGB half-float working space by default, with an optional float working mode matching export; both convert to their output profiles. The stock response is still a study model rather than a measured emulsion profile.

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

Preview rendering runs in a separate actor with a 16-bit half-float extended linear sRGB working buffer by default and an optional 32-bit float mode. Rapid control changes are debounced and older results are discarded. Full-resolution JPEG and 16-bit Display P3 TIFF exports run in a separate actor with a 32-bit float working buffer, so export does not freeze the editor. Each background job retains access to its source file until it completes. A Sony ARW export was verified at 4672 × 7008 pixels and 16 bits per sample. This verifies the output container and working format, not a measured film response or guaranteed recovery of source detail.

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

## Session recovery, 24 September 2026

FilmLab records the path of the last successfully opened photo and reopens it on launch when the file still exists. It flushes the current per-photo edit document when the window disappears or the app leaves the active scene, alongside the normal short delayed save while adjusting controls. In the signed app, a JPEG test file reopened automatically after quit; a vertical crop position changed immediately before quitting restored as 0.57. The current app is unsandboxed and uses a local path for this convenience. A future sandboxed distribution should use persistent security-scoped bookmarks instead.

## Scene-light shaping before film, 24 September 2026

Develop now has Shadow Light and Highlight Light controls in EV. A stitchable Metal kernel measures scene-linear luminance relative to 0.18, blends broad tonal weights in log-light space, and scales all three RGB channels together before the stock's negative-density stage. At their zero defaults this stage is skipped, so existing edits keep their output. On synthetic neutral patches, +1 shadow EV raised a 0.018 input to 0.0336 while 0.18 and 1.8 stayed fixed; -1 highlight EV lowered a 1.8 input to 0.963 while 0.018 and 0.18 stayed fixed. With the Ektar study, the corresponding positive outputs changed from 0.0327 to 0.0515 in shadows and 0.597 to 0.470 in highlights. The signed app rendered both adjustments on the Sony RAW test copy and exported a 4672 × 7008 JPEG. These are creative tonal controls, not measured film-stock parameters.

## Per-photo undo and redo, 24 September 2026

FilmLab now keeps up to 50 edit snapshots in memory for the active photo. Rapid changes within 500 ms form one undo step; opening another photo clears the history. Undo and Redo restore all saved controls, including RAW decoder settings, and trigger a RAW re-decode when those settings change. The signed app restored Shot Exposure from +1.59 to zero and reapplied it with Redo; a new Development edit cleared Redo; undoing a Linear RAW input toggle restored that decoder mode. Persisted edit files retain the currently applied state. The history is intentionally session-local and is not yet a multi-session edit timeline.

## Eight-family Color Mixer, 24 September 2026

Color now offers Red, Orange, Yellow, Green, Aqua, Blue, Purple and Magenta hue families, each with hue, saturation and luminance controls. A soft hue and chroma mask is computed from the graded pixel before any mixer band runs. Each active band then adjusts the accumulated image, while its mask remains tied to that original graded pixel so shifting one hue does not cause it to enter another band. The default zero values skip all mixer passes and preserve existing edits. This is a creative RGB control after film and tonal grading, not an emulsion spectral model.

The Metal probe checked that red desaturation and luminance affect a red patch while leaving a blue patch and neutral gray unchanged, and that the blue hue control changes a blue patch. The signed app opened the JPEG test copy and set Orange saturation to +0.4. It exported both that setting and a zero-mixer baseline with the same saved 1:1 crop at 4672 × 4672 pixels. Core Image comparison after reducing both JPEGs to 256 × 256 found 34,628 of 65,536 pixels differed by more than three 8-bit levels; mean absolute RGB differences were 1.61, 0.37 and 5.93 levels. Reopening the JPEG restored Orange saturation at +0.4. A prior RAW slider interaction visibly changed warm regions of the Sony test copy. The same signed app exported the Sony RAW test copy at 4672 × 7008 with Orange saturation at zero and +0.4. In a 256 × 256 comparison, 33,241 pixels differed by more than three 8-bit levels, with mean absolute RGB differences of 1.01, 0.17 and 3.75 levels. The RAW test edit was returned to zero. App-relaunch persistence and precise preview/export color parity remain to be checked.

## Fine straighten, 24 September 2026

Framing now saves a -15° to +15° straighten angle per photo. Rotation happens after quarter-turn orientation and before the chosen crop ratio. The rotated image is cropped to a centered rectangle at its original aspect ratio whose four corners stay inside the source; the ratio crop and its position controls then operate within that safe rectangle. This avoids empty corners but discards progressively more edge pixels as the angle grows. Zero degrees retains the old geometry for saved edits. The same framing function feeds preview, Before/After and full-resolution export.

A geometry probe checked zero-angle identity, quarter-turn dimensions, square crop and opaque output corners at ±7.5° and ±15°. The signed app showed +3° on the Sony RAW test copy and exported 4338 × 6508 from its 4672 × 7008 input. The JPEG test copy retained its existing 1:1 crop and position, showed +3°, exported 4338 × 4338 and restored the angle after reopening. Both test copies were returned to zero degrees. Freeform and perspective cropping remain unavailable.

## Stable grain, 24 September 2026

Grain previously used `CIRandomGenerator`, which could choose a new pattern whenever an edit was rerendered. The stitchable grain kernel now hashes its destination pixel coordinates to create repeatable monochrome noise, weighted by output luminance. It runs before framing and uses the same graph for preview and export. At 100% zoom, the pattern remains tied to image pixels; a fit preview averages the high-frequency texture as it scales down. This is still a provisional digital noise model, not measured grain for a film stock. Existing saved grain amounts keep their values, but their visible noise pattern changes with this revision.

A 64 × 64 linear-light Metal probe found identical pixels across two new graph builds and spatial variation on a constant gray patch. The half-float preview and float export contexts agreed in that probe. In the signed app, two 4672 × 7008 RAW-source JPEG exports with Grain at 0.1 were byte-identical; two 4672 × 4672 JPEG-source exports at the same setting were also byte-identical. The JPEG-source grain-on export differed from a grain-off export. Both test copies were returned to Grain 0. This verifies repeatability, not photographic grain accuracy or exact visual parity after the fit preview is downsampled.

## Endura Premier paper study, 24 September 2026

The Ektar stock now has an optional Endura Premier paper response. Kodak E-4070's representative Status A red, green and blue paper curves were approximately read into `Research/endura-premier-paper-tone.csv`; `FILM-STOCK-SOURCES.md` records the source, graph coordinates and uncertainty. The negative density is mapped to assumed paper exposure, then to density and relative reflectance. This shares the Paper Exposure and Paper Strength controls with the Portra Endura study while saving the two paper selections separately per photo. The paper balance and gray aim are provisional.

The Metal probe checked an Ektar neutral patch at -2/0/+2 paper exposure: increasing paper exposure darkened the output while the zero-exposure 0.18 patch stayed approximately neutral. The signed app opened a JPEG test copy, showed the active paper preview and exported a 4672 × 4672 JPEG; switching the paper stage off changed 63,820 of 65,536 sampled pixels by more than three 8-bit levels in a 256 × 256 comparison. The signed app also opened the linear Sony RAW test copy and exported a 4672 × 7008 JPEG with the Premier stage enabled. These checks establish that the option runs through both input paths, not that its colors match an optical print.

## Local scene-light adjustment, 24 September 2026

A new Local panel saves one elliptical radial exposure adjustment per photo. Position, size, feather and ±2 EV are defined in normalized source coordinates. A Core Image gradient blends an exposure-adjusted copy with the untouched scene-linear input before the film negative stage, so the selected area's light flows through the same exposure-dependent stock and paper response as the rest of the photo. Zero EV skips the graph. This is a geometric area adjustment, not a subject mask; its center is relative to the unrotated source and is adjusted with sliders.

The image probe checked unchanged output at zero EV, a roughly one-stop center change, an unchanged corner, and a moved darkening area without opposite-corner spill. In the signed app, the Local controls rendered on both the Sony RAW and JPEG test copies, and full-resolution JPEG exports measured 4672 × 7008 and 4672 × 4672. Compared with an otherwise identical zero-adjustment JPEG export at 256 × 256, the JPEG-source local export changed 34,143 of 65,536 pixels by more than three 8-bit levels, with mean absolute RGB differences of about 13.0, 13.0 and 12.9 levels. Undo restored zero exposure on the JPEG; reopening the RAW restored its test exposure, then that copy was returned to zero. The Endura Premier toggle now triggers preview and edit saving when changed.

## Radial mask view, 24 September 2026

The Local panel can temporarily show the radial adjustment mask as a grayscale canvas. It uses the same rotation, straighten and crop function as the edited image, so its visible coverage can be checked against the current framing. The mask view is transient, hides the output histogram while active, and closes when switching away from Local, opening a photo, or using Before/Compare. It is excluded from edit documents and the export graph. Position remains controlled in normalized, unrotated source coordinates.

The mask probe found a white selected center and black distant corner. In the signed app, the mask displayed on the Sony RAW and on the JPEG test copy with a 90° rotation and square crop; switching panels restored the photo and histogram. Exporting the JPEG while the mask was shown produced a file byte-identical to a prior export of the same zero-local-exposure edits with the mask hidden.

## Multiple radial light areas, 24 September 2026

Local now supports up to eight independent radial areas per photo. Each stores exposure, normalized center, size, feather and an inversion flag. The areas run sequentially in scene-linear light before the film stage, so overlapping adjustments compound. The Area picker chooses which mask is shown; Add and Remove participate in Undo/Redo and the saved edit document. Existing single-area edits are decoded into Area 1 from their former scalar fields. A temporary selection is not stored, and opening a photo selects the first area. This remains geometric dodge and burn, not a painted or subject-aware mask.

The image probe checked that inversion leaves its center unchanged while darkening a distant corner, and that a second area can affect the edge without erasing the first area's center adjustment. In the signed app, an inverted -1.06 EV Area 2 darkened the JPEG test copy's edges; its 4672 × 4672 export differed from an otherwise identical zero-local-area baseline in 51,877 of 65,536 sampled pixels by more than three 8-bit levels. Reopening the JPEG restored two areas and the second area's inversion and exposure. The signed app also rendered a +1.06 EV second area on the Sony RAW copy and exported a 4672 × 7008 JPEG. Both test copies were returned to one inactive area. A separate old-format edit fixture restored +1.25 EV with its saved 0.70/0.30 center, 0.20 size and 0.80 feather as Area 1, then was removed.

## Click-to-place radial areas, 24 September 2026

The Local panel can arm Place on photo, then accept one click in the fitted image to position the selected radial area. The click is mapped from top-left canvas coordinates through the current crop, straighten and quarter-turn rotation to the original source's normalized coordinates. Clicks outside the displayed image are ignored. The mode closes after a successful placement, or when changing panels, opening another photo, showing the mask, using Before/Compare/100%, or cancelling. Placement is an ordinary saved edit with Undo/Redo; the temporary placement banner is excluded from export.

The framing probe covers unframed points, all three nonzero quarter turns, a centered and shifted square crop, a 10° straighten and an out-of-bounds click. In the signed app, clicking the subject on a quarter-turned, square-cropped JPEG moved the selected area to source coordinates about 0.53/0.45; its framed mask centered on the clicked point, and Undo restored 0.50/0.50. On the Sony RAW with 3.17° straighten, clicking the climber moved the area to about 0.59/0.42; the mask centered on that point and a +1.06 EV version exported at 4322 × 6482 pixels. Undo returned local exposure, position and straighten to their prior values.

## Freeform crop verification (2026-09-24)

The Framing workspace now supports a non-destructive freeform rectangle after rotation and straighten. Width, height, and center use normalized coordinates; a temporary full-frame view exposes draggable bounds while the actual preview and export use the selected crop. The rectangle and ratio persist with the photo edits, and older edit records decode with a default centered rectangle. The framing probe checks output dimensions, source-point mapping, and edge clamping. Metal rendering, grain, local-light, and framing probes pass; the release app builds and passes strict code signing. In the signed app, the RAW test file `FilmLab-linear-default.ARW` displayed the rectangle and dragging it changed horizontal and vertical center values.

### Freeform export check

I verified the signed app through its Save dialog on both input types. `FilmLab-linear-default.ARW` exported with 80% width and height to a 3737 × 5606 JPEG from its 4672 × 7008 source. `FilmLab-jpeg-default.jpg`, with its saved quarter-turn rotation, exported at 5606 × 3737. Two exports of the JPEG with the same edit settings, once with the temporary crop bounds visible and once hidden, were byte-identical (SHA-256 `a003634f4e5af08aa049e66d5b691bf37ca6892c1512118fecf986a273abfbc6`). This checks that the bounds overlay does not enter the render/export pipeline. It does not establish pixel-level equivalence between RAW and JPEG, whose input processing differs.

## Cross-photo settings verification (2026-09-24)

The signed app copied settings from `FilmLab-jpeg-default.jpg` and pasted them onto `FilmLab-linear-default.ARW`. The RAW Film panel changed to the JPEG source's 0.40 EV paper exposure and 0.70 stock amount; the photo also acquired its saved framing. The Develop panel still showed the RAW source's 5634 K temperature, 4 tint, highlight recovery and linear RAW input. A single Undo restored the prior RAW look. Settings transfer is intended as a starting point: different RAW/JPEG input transforms can make the same settings look different.

## Background image decoding (2026-09-24)

File type detection and RAW/JPEG decoding now run in an `ImageDecoder` actor. The editor keeps the current photo visible while a new file opens, shows an Opening photo progress indicator, and uses a version check to discard an older open result after a newer request. RAW white-balance and decoder-mode changes use the same off-UI decoder. On the signed app, the saved Sony ARW reopened successfully; opening `FilmLab-jpeg-default.jpg` then restored its saved Ektar/paper grade, and its Develop panel excluded RAW-only controls. This is a functional UI check, not a measured latency or memory benchmark.

## Graduated scene light (2026-09-24)

Each saved local area can now be radial or a smooth linear gradient. The linear mask is defined by a source-space center, direction and transition width; it blends a scene-linear exposure adjustment before the selected negative and paper response. New linear areas initialize their source angle so the gradient appears vertical after the current framing rotation and straighten. The angle then stays anchored to the source if the framing changes. Inversion swaps the affected side. Existing radial records decode as radial without losing their positions or exposure. This is a geometric light mask, not a subject-aware or measured film characteristic.

The local probe verified the mask's white, black and half-strength regions, its one-stop effect on only one side, and old radial JSON compatibility. In the signed app, the rotated JPEG displayed a vertical mask and about +1 EV visibly changed its lower region; the unrotated Sony RAW showed the same mask orientation and foreground brightening. A RAW render with the gradient exported to a 3737 × 5606 sRGB JPEG, reflecting that test photo's pre-existing 80% freeform crop. The temporary test exposures were returned to zero and the areas restored to radial.

## Painted scene-light areas (2026-09-24)

A local area can now save source-space brush strokes, each with its own size. The app maps display drag positions through rotation, straighten and crop back to the original image. A grayscale mask is rasterized at up to 4096 pixels on its longest side, optionally softened, and blends a scene-linear exposure adjustment before the film stock. Brush Size changes future strokes; Soft Edge affects all strokes in the area. Clear Strokes and the normal Undo stack are available. One area permits up to 100 strokes of up to 500 sampled drag points to bound edit-file size and rasterization work. This is a user-painted geometric mask, not automatic subject selection or measured emulsion behavior. The 4096-pixel cap can soften very fine brush edges on larger exports.

The local probe checked source-point placement, unaffected pixels, exposure effect, old radial JSON compatibility and old brush-stroke decoding. In the signed app, a Sony RAW and a rotated JPEG both accepted a drag stroke and showed it in the temporary mask view. The RAW stroke restored after reopening. At roughly +1 EV, exported JPEGs differed from zero-exposure baselines by more than three 8-bit levels in 262,966 pixels (RAW source) and 370,508 pixels (JPEG source). The exports used the photos' existing saved crops and were 3737 × 5606 and 5606 × 3737 respectively. Test areas were removed afterward. These checks establish a working local edit on both decode paths; they do not establish film-stock accuracy.

### Brush eraser

Painted areas now offer Paint and Erase modes. Erase strokes remove selected mask coverage in drawing order, keep their own brush size and source-space coordinates, and participate in saved edits and Undo. Older strokes decode as paint. The mask probe checked that an erase point clears only its target and preserves the rest of the stroke. In the signed app, a painted horizontal stroke on both the RAW and the quarter-turned JPEG showed a clear gap after erasing through its center. The temporary areas were removed after inspection.

## Export source protection (2026-09-24)

The exporter now rejects an output path that resolves to the open source photo. JPEG already used atomic data writing; TIFF now renders to a sibling temporary file, then moves or replaces it after a successful render. A probe verified that a same-path JPEG request preserves its source bytes, a JPEG output decodes, and a 16-bit TIFF can replace an existing output without leaving a partial destination. In the signed app, the JPEG test photo exported a 5606 × 3737 JPEG and the Sony RAW test photo exported a 3737 × 5606, 16-bit TIFF through the Save panel. These exports check file safety and format, not film-stock accuracy or every filesystem failure mode.

## Negative-density endpoint continuity (2026-09-24)

Beyond the last Portra and Ektar chart sample, the density study now continues the fitted endpoint tangent rather than the final segment's average slope. The neutral-input Metal probe samples intermediate negative density without display color conversion and checks slope continuity on both sides of each upper endpoint. It passes with the new continuation; the prior kernel fails on Ektar's red layer, whose sampled slope jumps from about 0.380 to 0.424 density per log-exposure unit. This removes an artificial highlight transition, while the beyond-chart response remains unmeasured.

The signed app reopened the Sony RAW and JPEG test images and rendered Ektar at roughly +2.12 Shot Exposure. The RAW preview retained visible rock and clothing separation; the JPEG preview reported 44.5% near-white pixels and showed extensive bright-area clipping. Both test edits were restored to zero. This comparison illustrates the existing JPEG highlight limitation; it does not prove stock accuracy or directly quantify the small endpoint change.

## Saved edit recovery (2026-09-25)

Saved edit loading now distinguishes a missing record from an unreadable or undecodable one. An undecodable record is copied to a recovery JSON file before FilmLab permits new saves; if the copy cannot be made, saving for that photo pauses rather than overwriting the original. The inspector shows a brief notice and a Finder button for the backup. A file-store probe covered missing, valid, damaged, backed-up and subsequently saved states. In the signed app, a disposable JPEG copy with invalid edit JSON reopened with the notice, revealed the selected backup in Finder, saved a new +1.12 EV edit while the backup bytes stayed unchanged, and was then removed. Reopening the normal Sony RAW restored its Ektar settings without a recovery notice. This protects the original bytes; it does not repair damaged edits automatically.

## Portable looks (2026-09-25)

The Settings menu can save the current edit parameters in a versioned JSON look file and apply one to another photo. It uses the same transfer behavior as Copy/Paste Settings: the grade, local lights, texture and framing transfer, while the target keeps its own RAW decode mode, highlight recovery and camera white balance. The file omits the originating photo's camera white balance. Applying a look is one Undo step. The format probe checks a round trip and rejection of an unsupported version.

In the signed app, a look saved from the Sony RAW applied to a JPEG, changing its Paper Exposure from 0.40 to 0 EV and Stock Amount from 0.70 to 1.00; Undo restored both JPEG values. A look saved from that JPEG applied to the RAW, changing its paper/stock settings in the other direction while the RAW remained at 5634 K, tint 4, highlight recovery on and Linear RAW input on. Undo restored the RAW's prior settings. These checks establish a reusable settings workflow, not matched color between the two input types or a calibrated stock profile.

## JPEG input balance (2026-09-25)

Develop now offers JPEG input warmth and tint before scene-light shaping and the film response. The controls use Core Image's temperature-and-tint filter on the tagged JPEG decode; they default to zero and remain local to each source photo when settings or a portable look are transferred. RAW continues to use its decoder white balance. This is a visual cast correction for an already rendered image, not recovery of the original scene illuminant or clipped JPEG channels.

In the signed app, the Sony JPEG test copy rendered and exported with +0.65 input warmth and -0.54 input tint. Against the same edit at zero input balance, 13,877 of 16,384 pixels in a 128 × 128 comparison differed by more than three 8-bit RGB levels; mean absolute differences were 12.09, 5.08 and 4.28 levels. The values restored after relaunch, then were returned to zero. The signed app reopened the Sony RAW with its 5634 K, tint 4, highlight recovery and linear decoder controls, and without JPEG input controls. This verifies the feature on both input paths, not colorimetric accuracy or a measured stock match.

## Local color before film (2026-09-25)

Each local area can now adjust warmth and tint as well as exposure before the film response. The same existing radial, linear and painted masks blend the adjusted scene with the untouched scene, and overlapping areas remain sequential. Older edit records decode with neutral local color. Zero exposure, warmth and tint skips the area's processing. The temperature-and-tint filter is a visual RGB correction; it does not model spectral interactions in film or recover information lost in JPEG rendering.

The local rendering probe checks selected and unselected pixels for radial color, then confirms that linear and painted color follow their respective masks. In the signed app, a +0.61 warmth and -0.53 tint radial area changed 5,023 of 16,384 sampled RAW-source export pixels and 6,163 JPEG-source pixels by more than three 8-bit RGB levels versus neutral exports. Both showed the localized cast in preview, and values restored after switching photos. The temporary RAW area was removed and the JPEG area's controls returned to zero afterward. These comparisons verify processing and persistence, not color accuracy.

## File-backed rendered-image input (2026-09-25)

The non-RAW decoder now constructs a Core Image image from the source URL instead of first reading the whole file into a `Data` buffer. FilmLab retains source access while previewing and exporting. The Develop panel's pre-film rendered-input controls also apply to TIFF and other supported non-RAW images. A 16-bit TIFF remains a high-precision rendered image with its own profile, not a scene-referred RAW replacement.

A two-pixel 16-bit TIFF probe places linear red values 0.0005 apart; the decoded values remain 0.0004867 apart, below one 8-bit step. The signed app opened and rendered a 160 MB, 3737 × 5606 Display P3 TIFF from the Sony RAW test photo, then exported a full-size sRGB JPEG. It reopened the Sony RAW with its camera white-balance controls. The Sony JPEG reopened with rendered-input controls and produced an export byte-identical to the prior neutral export from the earlier data-backed decoder; capture date, camera, lens, orientation and output dimensions stayed correct. These checks establish precision preservation and compatibility for the tested files, not a general memory benchmark or scene-color calibration.

## Precompiled film kernels (2026-09-25)

The signed app now bundles a Metal library built from the same stitchable source used by direct SwiftPM development runs. `Scripts/build-kernels.sh` extracts the source, invokes Xcode's Metal compiler with `-fcikernel`, then uses the normal metallib link mode that retains the stitchable functions. FilmLab loads the bundled library at startup when present and checks for its required kernels; a development executable without that resource compiles the source string as before. Building the bundle requires Xcode's optional Metal Toolchain component, which was installed through `xcodebuild -downloadComponent MetalToolchain` on the test Mac.

The rendering suite passed while loading the compiled library, and a separate source-only probe passed without it. The signed bundle contained an 84 KB library and passed strict code-signature verification. In the running app, both Sony RAW and JPEG previews rendered with Ektar and Endura Premier; their full-resolution JPEG exports were byte-identical to earlier source-compiled exports at the same saved settings. This validates this Mac and these render paths. It does not make the modeled film response more accurate or establish compatibility with other Metal GPUs and macOS versions.

## Edge detail (2026-09-25)

Texture now offers a luminance-based Edge detail control before halation and grain. It compares each pixel with a 1.5-source-pixel Gaussian low-pass image, bounds the luminance adjustment, and scales RGB together to limit hue shifts. Zero skips the spatial pass. Older saved edits decode with zero, and the control transfers with saved looks and copied settings. It is a creative acutance adjustment, not a measured stock-specific edge response. Preview downscaling occurs after this effect, so Fit view can hide it; judge its final appearance at 100% or in an export.

The rendering probe checks opposite sides of a synthetic edge, flat regions, and preview/export working-format agreement (maximum channel difference 0.00049). In the signed app, the control restored at 0.87 after reopening the Sony JPEG and after switching back to the Sony RAW. Both produced full-resolution JPEG exports at 5606 × 3737 and 3737 × 5606 respectively. Compared with earlier neutral exports, center 1024 × 1024 crops had 467,964 changed JPEG-source pixels and 344,408 changed RAW-source pixels above two 8-bit levels. The temporary settings were returned to zero. These checks show that the control affects both paths and persists; they do not establish photographic or stock accuracy.

## JPEG input headroom and exposure comparison (2026-09-25)

Develop now reports the fraction of a JPEG's sampled decoded pixels whose display-sRGB red, green or blue channel reaches at least 250/255. It samples a 256-pixel-longest-side image during import, before FilmLab's input balance and film stage. The readout is limited to JPEG: high-bit-depth TIFF and RAW have different meanings for values above display white. It is a prompt to inspect bright input areas, not proof of clipping or a count of unrecoverable pixels. A clipped source channel cannot be reconstructed by rolling off its displayed brightness. A synthetic half-white JPEG produced a 50% readout; the 16-bit TIFF probe reported no JPEG diagnostic.

The signed app opened the same Sony scene as linear-decoded RAW and camera JPEG, selected Ektar 100 with Endura Premier, and exported each at Shot Exposure -2, 0 and +2 EV. Stock Amount was 1.0 and Paper Strength 0.5 on both; the JPEG's Paper Exposure was approximately -0.0065 EV versus 0 on RAW because of slider precision. The JPEG's saved 0.4 EV paper setting and 0.7 Stock Amount were restored afterward. The table gives 256 × 256 display-sRGB luminance percentiles from those six full-resolution exports:

| Input | -2 EV p10 / median / p90 | 0 EV p10 / median / p90 | +2 EV p10 / median / p90 |
| --- | --- | --- | --- |
| RAW | 27 / 37 / 115 | 28 / 73 / 195 | 39 / 156 / 224 |
| JPEG | 27 / 77 / 138 | 30 / 160 / 205 | 47 / 211 / 229 |

The JPEG input's camera tone curve and bright plateau remain visible throughout the series. The film stage compresses output whites enough that the output histogram says 0.0% near white, while the new JPEG input readout says 13.4% of sampled pixels have at least one channel near its display limit. This discrepancy was the reason for adding the input readout. The percentiles show a substantial input-normalization gap at the same nominal film settings; they do not isolate a measured film response, identify the camera's JPEG tone curve, or establish stock accuracy.

## Rendered input tone (2026-09-25)

Develop now offers Input tone for JPEG and other rendered files before input color balance, scene-light shaping and the film response. It scales all three nonnegative RGB channels together after applying a power slope to extended-linear luminance relative to 0.18. A value below 1 compresses the available input tonal range toward middle gray; a value above 1 expands it. The neutral value 1 skips the stage. This is an adjustable approximation for a baked camera or scanner tone curve, not an inverse profile; it cannot recover clipped values or recreate scene spectra. RAW uses its decoder and does not expose this control. The setting stays with its source photo when copying or applying a look, and older edit records default to 1.

The Metal rendering probe checks middle-gray anchoring, opposite shadow and highlight behavior for slopes 0.5 and 1.5, and stable RGB ratios on a colored patch. In the signed app, the Sony JPEG at Input tone 0.5 showed a flatter preview and exported a full-resolution 5606 × 3737 JPEG. Against the same source and saved grade at Input tone 1, its sampled display-sRGB luminance p10/median/p90 moved from 28/147/215 to 50/123/159; 1,043,419 of 1,048,576 pixels in the center 1024 × 1024 crop differed by more than two 8-bit levels. The value restored after relaunch and was returned to 1. Neutral JPEG and RAW exports were byte-identical to their pre-feature baselines. The Sony RAW reopened with its white-balance and linear-decoder controls and no rendered-input tone control. This verifies the stage and source-local workflow, not that 0.5 is the correct inverse response for the camera JPEG.

## Output gamut diagnostic (2026-09-25)

The output histogram now also samples the developed image in extended-linear sRGB before 8-bit preview conversion. It reports the fraction with any RGB channel outside the nominal zero-to-one sRGB range. A two-pixel float probe with one red channel at 1.25 reports 50%, confirming the diagnostic sees values hidden by display encoding. In the signed app, the Sony JPEG with its saved Ektar settings reported 0.0% at 0 EV and 59.2% at +2.88 EV; the 8-bit output histogram reported 55.1% near white at the latter exposure. Undo restored both readouts. The Sony RAW opened and rendered, reporting 0.0% at both 0 and +2.88 EV with its own Ektar settings; its exposure was restored. This is a downsampled working-space warning, not a measurement of sensor clipping, a gamut map of the exported file, or proof of film-stock color accuracy.

## Spatial grain study (2026-09-25)

A CC0 Ektar 100 flat-field negative scan provided a reference for grain spatial correlation at 4,000 dpi; the measurements and their scanner limitations are in `FILM-STOCK-SOURCES.md`. FilmLab now blends fine deterministic noise with a correlated field that spans roughly 2–3 source pixels at Grain Size 1. The synthetic flat-field probe measured one- and two-pixel correlations of 0.80 and 0.46; Grain Size 0 retains the former independent noise with 0.004 adjacent correlation. Existing saved edits without a size field decode to 0, while newly created edits default to 1. The strength remains luminance weighted and adjustable, not fitted to a measured positive scan.

The signed app reopened the Sony RAW and JPEG samples, displayed Grain and Grain Size 0 for their existing saved edits, and rendered Grain 0.77 with Size 1 at 100% zoom. Both exported as full-size JPEGs: 3,737 × 5,606 from RAW and 5,606 × 3,737 from JPEG. Undo restored each sample's prior texture settings. This checks both editing paths and output dimensions, not a perceptual match to Ektar prints or scans.

## Output shoulder (2026-09-25)

Develop now has an optional final highlight shoulder after film response, color grading and texture. Above 0.75 linear peak RGB, the full-strength function approaches 1 smoothly and scales all RGB channels together. It defaults to zero, so earlier saved edits keep their prior rendering. It is a manual output tone choice, not a film density measurement or a way to reconstruct clipped source pixels. A synthetic extended-linear patch check confirms dark values stay fixed, a 2/1/0.5 patch comes below display white while retaining its channel ratios, and half-float preview agrees with float export within 0.002.

In the signed app, the Sony JPEG at +2.88 EV Shot Exposure changed from 59.2% sampled outside sRGB and 55.1% near white to 0.0% outside and 21.1% near white at Shoulder 1. On the Sony RAW, +2.32 EV Output Exposure changed from 30.3% outside and 25.7% near white to 0.0% outside and 0.2% near white. Both exported as full-size JPEGs, 5,606 × 3,737 and 3,737 × 5,606 respectively. Both test photos were returned to their saved neutral exposure and Shoulder 0 afterward. These are output diagnostics for two photos; they do not validate stock-specific highlight behavior.

## Output tone curve (2026-09-25)

Develop now has shadow, midtone and highlight output curve points at input luminances 0.2, 0.5 and 0.8. A monotone cubic interpolation joins these to fixed black and white endpoints. It adjusts extended-linear luminance after film and paper processing and scales RGB together, so it changes brightness without intentionally shifting hue. Values above display white continue along the final tangent until the optional output shoulder or output conversion acts on them. The neutral values skip the kernel, and older saved edits decode with all points at zero. This is a manual finishing curve, not a measured film response or an independent RGB channel curve.

The rendering probe checks neutral output, each control point, monotonicity for opposite extreme settings, and RGB ratios on a colored patch. The signed app showed the controls for the Sony RAW and JPEG samples. Raising the RAW shadow point to 0.08 and lowering the JPEG midtone point to -0.06 both changed their previews without a rendering error. These checks establish the interaction path, not stock accuracy.

## Vibrance (2026-09-25)

The Color workspace now has a master Vibrance control after film response, output tone and three-way color timing. It adjusts RGB chroma around extended-linear luminance, with a smooth weight that fades as source saturation rises. Positive values emphasize muted colors; negative values reduce their chroma. The stage preserves neutral pixels and luminance. Negative extended-gamut channels pass through unchanged rather than being clipped. Zero skips the stage and older saved edits decode to zero. This RGB-based adjustment is a creative grade, not a perceptual color model or measured film dye behavior.

The rendering probe checks neutral and colored patches, luminance preservation, stronger relative action on muted color, and an out-of-gamut patch. In the signed app, +0.78 changed the Sony RAW preview, and +0.77 changed the JPEG preview. A full-size 5,606 × 3,737 JPEG export at +0.77 differed from a neutral export in 76.1% of pixels by more than two levels in at least one 8-bit channel. Both sample settings were returned to zero. The export comparison demonstrates the setting reaches final rendering; it does not establish a film-stock match.

## Photo opening workflow (2026-09-25)

The Open toolbar menu lists up to ten recent source paths and the macOS File menu offers Open Photo with Command-O. Recent entries whose files no longer exist are hidden at startup and pruned from storage after the next successful open. Clearing the list also clears the last-photo resume pointer; it leaves source files and saved edits untouched. The signed app reopened the Sony JPEG and RAW from the recent menu, restoring each photo's separate Ektar and paper settings. Command-O opened the system file picker from the File menu. These checks cover local files in the current unsandboxed build; portable security bookmarks for sandboxed distribution are not implemented.

## TIFF export orientation metadata (2026-09-25)

An export probe found that a 16-bit TIFF with already oriented pixels retained an input orientation tag of 8. A photo viewer could rotate those pixels again. Both JPEG and TIFF now set output orientation to 1 and update EXIF pixel dimensions after framing while preserving available camera and capture-date fields. The probe checks a source tagged orientation 8, reads both exported formats through ImageIO, and verifies orientation, dimensions, camera make and capture date; TIFF remains 16 bits per sample. The signed app also exported the saved Ektar grades from the Sony RAW and JPEG samples as 3,737 × 5,606 and 5,606 × 3,737 Display P3 TIFFs at 16 bits per sample. Their source photos were not altered. This checks the metadata path and two local files, not all third-party viewers or every metadata field.

## Preview-only sRGB gamut warning (2026-09-25)

The editor can now mark output pixels outside the nominal extended-linear sRGB range before 8-bit display conversion. Red indicates at least one channel above one, blue indicates a channel below zero, and magenta indicates a non-finite value. The toggle changes only the rendered preview; histogram calculations use the unmarked image, and exports use the original developed image. In split comparison the warning applies to After, while Before stays unmarked. A synthetic probe checks unchanged in-range RGB, red and blue warning behavior, a changed preview, and an unchanged out-of-range fraction.

In the signed app, temporary +2.98 EV output exposure on the disposable Sony JPEG reported 63.0% sampled outside sRGB and showed red over the bright sky and rock. A full-size 5,606 × 3,737 JPEG exported with the warning visible contained the normal photograph without red marks. Temporary +2.41 EV output exposure on the disposable Sony RAW reported 31.6% outside sRGB and marked its bright sky and rock. Undo restored both saved exposures to zero and the warning toggle was turned off. The warning helps locate output conversion risk; it cannot establish sensor clipping, recover a baked JPEG highlight, or predict whether a flagged color fits in Display P3.

## Edit records across file renames (2026-09-25)

FilmLab now keys its primary saved edit record by a same-volume file identity: volume UUID when available, filesystem file number, and creation time. It also writes a path-keyed copy. On first reopening an older photo, the previous path-only record is copied to the identity location. A missing path copy is rebuilt from a valid primary record when the photo opens. This lets a rename or same-volume move retain edits and lets an in-place replacement at the same path recover the path copy. Damaged primary records still follow the existing backup-before-save recovery path.

The storage probe verified same-volume rename identity, distinct identity for a copied file, migration without deleting the legacy record, and recovery from the path copy after replacing a file at the same path. In the signed app, a disposable Sony JPEG copy kept +1.44 EV Shot Exposure after being renamed, and a disposable Sony RAW copy kept -1.02 EV after the same operation. Both values also loaded in the final signed build after the volume UUID refinement; the original test photos and their saved grades were unchanged. This does not cover a move between volumes, every network filesystem, or an identity change combined with a path change. A copied photo intentionally starts a separate edit history.

## Extended-linear point inspection (2026-09-25)

The inspector can sample a point in Fit view and show decoded input and final developed output as extended-linear sRGB values with four decimal places. It maps the click through rotation, straighten and crop to the source point. Sampling runs on a background actor in 32-bit float buffers, and a changed edit clears the prior readout. These are point values before JPEG or Display P3 export conversion; the displayed preview remains sRGB. RAW input has already passed through the macOS decoder, demosaic, camera profile and white balance. JPEG input is baked and cannot regain missing scene information.

The float probe retained a 0.0001 red-channel difference and a green value above 1, including with nonzero image origins. The signed app sampled a disposable Sony JPEG at input luminance 0.0508 and developed luminance 0.1393. Raising Input Tone to 1.32 left input at 0.0508 and changed developed luminance to 0.0950; Undo restored the edit. A disposable Sony ARW sampled input luminance 0.0322 and developed luminance 0.0196. The samples demonstrate the inspection path and edit response, not film-stock calibration or sensor-level measurement.

## 16-bit sRGB TIFF handoff (2026-09-25)

Export now offers separate 16-bit TIFF choices for sRGB and Display P3. Both use the same developed image, full-resolution float working context, atomic TIFF replacement, and metadata normalization; only the output ICC color space differs. This lets an external editor receive a high-bit-depth file in its expected color space. sRGB output cannot retain colors outside sRGB, and a 16-bit TIFF made from a JPEG does not recover detail absent from the JPEG.

The export probe checked each TIFF's embedded color space, 16-bit depth, dimensions and orientation. In the signed app, the disposable Sony RAW and JPEG copies each exported a 4672 × 7008 sRGB TIFF with an sRGB IEC61966-2.1 profile and 16 bits per sample. The large temporary files were removed after inspection. The original source files were not altered.

## Live point inspection (2026-09-25)

The selected point now remains marked in Fit view and is sampled again after the preview renders a changed edit. Opening another photo clears the selection; switching the inspector off clears it too. In the signed app, a point on the disposable JPEG kept input luminance at 0.0254 while Shot Exposure changed developed luminance from 0.0721 to 0.0216. A point on the disposable RAW kept input luminance at 0.0182 while Shot Exposure changed developed luminance from 0.0134 to 0.0367. Undo restored each earlier output readout and saved exposure. These checks show that a grade changes the developed value at a stable point; they do not establish film-stock accuracy.

## RGB output histogram (2026-09-25)

The output histogram now overlays red, green and blue channel curves on a dim luminance fill. The curves share one height scale. Separate percentages show pixels with each sRGB output channel at or above 251/255 in a downsampled preview. The existing outside-sRGB percentage still samples the developed image before output conversion. Near-white output channels reveal which color is approaching the display ceiling, but do not prove sensor clipping or missing detail in a JPEG.

The synthetic preview probe produced a near-white red channel in one of two pixels while green and blue stayed below that threshold; it also verified that the gamut warning did not alter the diagnostic. In the signed app, the disposable Sony JPEG reported R 34.8%, G 32.9%, B 27.9% at its saved +1.44 EV Shot Exposure. Lowering exposure to -1.05 EV moved all three below the sampled near-white threshold, and Undo restored them. The signed app also displayed the RGB curves on the Sony RAW and updated their shape as exposure changed; its saved grade was restored afterward.

## Precise numeric controls (2026-09-25)

Each continuous slider now has an editable value field. Comma and period decimal separators are accepted. Enter commits a value within the control's range; an out-of-range entry is bounded, and invalid text resets to the current display. The field keeps its draft separate from the underlying Double, so opening a photo or focusing a rounded display does not quantize a saved value. SwiftUI's direct value-bound field did quantize a disposable JPEG's 1.439… EV setting to 1.44 during the first trial; it was replaced before this build.

The numeric probe checks decimal parsing, bounds, invalid input and ungrouped temperature formatting. In the signed app, typing JPEG Shot Exposure 1.25 EV updated the image; typing 9 clamped to the +3 EV limit, and Undo restored the previous grade. On the disposable RAW, an invalid temperature entry and focus loss left the underlying 5633.909… K camera value unchanged. Entering 6500 K updated the RAW preview; Undo restored the original value. The original photo files were unchanged.

## Input neutral-area correction (2026-09-25)

Develop now has a Pick neutral area control for RAW and rendered files. A click in Fit view maps through the current framing to a 32 × 32 decoded-input patch. FilmLab averages its extended-linear RGB, rejects very dark, near-white and extreme color ratios, and derives per-channel gains that make the patch neutral while preserving its linear luminance. The gains run before the film response and after macOS RAW demosaic, camera profiling and decoder white balance. They are per-photo input settings, so Copy/Paste Settings and look files keep the target's own correction. Clear restores unity gains. This is a user-chosen neutral correction, not a camera calibration, film stock measurement, or recovery of clipped JPEG data.

The float probe verified neutral output and retained luminance, including a source image with a nonzero extent, and checked rejection of unstable samples. In the signed app, a rock patch yielded R 0.92×, G 1.02×, B 1.08× on a disposable Sony RAW and R 0.94×, G 0.99×, B 1.32× on a disposable JPEG. RAW Undo/Redo worked and both corrections survived switching photos. A corrected RAW JPEG export and a baseline export were both 4672 × 7008 sRGB; a decoded pixel at (2000, 3500) changed from roughly (0.343, 0.261, 0.203) to (0.334, 0.261, 0.208). The disposable photos were returned to unity gains afterward. Those values demonstrate that the correction reaches the full-resolution export, not that the sampled rock was spectrally neutral.

## Backup recovery and catalog workflow (2026-09-25)

When an identity-keyed edit record is missing or damaged, FilmLab now tries the path-keyed copy. A damaged identity record is preserved before the valid path copy repairs it. If the identity record cannot be read or the repair write fails, the path grade can still load but saving pauses. The recovery probe covers missing, valid, damaged and unreadable primary records. In the signed app, a disposable JPEG with a deliberately malformed identity record reopened at its saved +1.75 EV Shot Exposure. Its path copy repaired the primary; the recovery file retained the exact malformed bytes. This has not been exercised on every filesystem failure mode.

The new Library view organizes references to original photos in named local catalogs. Import accepts multiple RAW and rendered images, shows an ImageIO thumbnail grid, and opens the first selection in the editor. A strip below the canvas switches between photos in the selected catalog. The existing per-source edit records remain the authority for the grade; catalog removal only removes references. A damaged catalog index gets a recovery copy before a new index can be saved. The library probe covers duplicate-free import, catalog creation and switching, persistence, removal, and damaged-index backup.

Catalogs can now be renamed. A photo's context menu or a multi-photo selection can copy or move references to another catalog without copying original files or edit records. A copied photo keeps the same saved grade in both catalogs. The library probe covers trimming invalid rename input, duplicate-free copy, move, and repeated transfer. In the signed app, a disposable Sony RAW reference was copied to a second catalog and a disposable JPEG reference was moved there; the source catalog retained the RAW and lost the JPEG. The verification catalog was removed afterward, with both references restored to the default catalog.

Library and filmstrip thumbnails now decode in an actor outside the main UI thread, prefer ImageIO's embedded thumbnail where available, and retain at most 128 decoded images. The signed app showed both disposable Sony ARW and JPEG thumbnails after launch, and clicking each in the filmstrip reopened its separate 0 EV grade. This verifies the tested files and UI path; thumbnail throughput for a large library has not been measured.

## Preview and export parity (2026-09-25)

A controlled 64 × 64 extended-linear RGB gradient, including values above display white, now passes through the normal preview renderer at 100% and the 16-bit sRGB TIFF exporter. After decoding both outputs into display-sRGB 8-bit pixels, the maximum channel difference was zero. This verifies that the tested full-scale preview and TIFF path agree after output conversion. Fit-view downsampling, JPEG compression, display color management, and real film-stock color accuracy remain separate questions. The signed app continues to open the disposable Sony RAW and JPEG through the filmstrip with their separate grades; this probe does not assert that their differently processed inputs should render identically.

## Catalog index repair (2026-09-25)

The library loader now checks structural invariants after JSON decoding. An empty catalog list, a selected ID with no matching catalog, duplicate catalog IDs or paths, and blank names are repaired before the view uses the index. FilmLab first preserves the original JSON in a recovery copy, then atomically saves the repaired index; if backup or save fails, saving pauses and the view shows a notice. The probe verifies that both catalogs and their distinct references survive repair. The signed app was restarted against its intact live index, showed the disposable Sony RAW and JPEG entries, and reopened the RAW with its separate saved grade. I did not inject a damaged index into the live app support directory; the recovery behavior is verified by the isolated file-backed probe.

## Output tint (2026-09-25)

Develop now pairs output warmth with a green–magenta tint control after the film response. Positive tint moves toward magenta; the default is zero, so existing edits retain their appearance. The value is part of the photo's edit record and follows saved looks, copy/paste, batch transfer, and undo through the existing settings structure. It changes the final grade, not the RAW decoder's camera white balance or rendered-image input tint. In the signed app, +0.40 visibly shifted a disposable Sony RAW toward magenta, while −0.40 shifted its paired JPEG toward green. Both values survived photo switching and an app restart, and the RAW retained its linear decoder mode and camera white balance. Both disposable grades were returned to zero tint. This is a creative color balance, not a measured stock dye or spectral response.

## Film-light color balance (2026-09-25)

Develop now also has warmth and green–magenta tint before the exposure-dependent stock response. They apply after decoded-input correction and local light/color areas, so the existing stock kernels receive changed RGB light rather than a fixed shift of their positive output. Both default to zero for compatibility with saved edits. An isolated rendering probe compares the same color balance before Portra density processing and after the positive output at −2 and +2 EV; the results differ at both exposures. In the signed app, disposable Sony RAW and JPEG previews changed under film-light edits of +0.35 warmth/+0.25 tint and −0.30 warmth/−0.20 tint respectively. Each photo kept its own values through switching and relaunch; the RAW retained its linear input and camera white balance. Both test grades were returned to zero. This is an exploratory input-color control, not a calibrated illuminant or spectral film model.

In the signed app, a verification catalog imported disposable Sony JPEG and ARW copies together. The strip showed both files. Setting JPEG Shot Exposure to +1.25 EV, switching to RAW, and switching back restored their separate +1.25 and 0 EV values. Copy Settings from JPEG and Paste Settings on RAW transferred +1.25 EV and Stock Amount 0.70 while preserving the RAW decoder path. The catalog and RAW grade survived an app relaunch; selecting the empty default catalog showed its own contents. The verification catalog was removed through the app's confirmation flow without deleting the photo copies. Catalog references currently use paths; there is no portable library package yet.

## Relinking moved originals (2026-09-25)

The Library view now labels missing originals and offers Locate Original. Relinking updates references in every catalog that contained the old path, avoiding duplicates. If the selected replacement already has an edit record, FilmLab keeps it. Otherwise it decodes the missing path's saved grade and writes copies under the replacement's path and file identity. The original edit record remains in place. A missing or damaged old grade does not prevent relinking, but the app tells the user no valid grade was found. This workflow depends on the user choosing the correct replacement; FilmLab cannot prove two files have identical pixels.

The relocation probe covers copied files with new identity, preservation of a target's existing grade, and catalog deduplication. In the signed app, disposable Sony ARW and JPEG copies were imported, edited to −0.85 and +1.15 EV respectively, copied to new paths, and removed from their old paths. Both entries appeared as missing. The first picker implementation lost the pending path when dismissed; after separating picker presentation from the pending path, Locate Original updated both entries. Opening the relinked ARW restored −0.85 EV, and opening the JPEG restored +1.15 EV. The source photos were disposable copies; stock color accuracy is unchanged.

## Batch settings transfer (2026-09-25)

The Library view now lets users select multiple photos and paste a copied grade onto them together. The same transfer rule as single-photo Paste Settings keeps each destination's RAW decoder mode, highlight recovery, white balance, and rendered-input corrections. The currently open source photo is skipped to avoid replacing its active state. A valid target edit record is saved in `Edits/BatchBackups/` with its source path before changes are written. Records needing recovery, missing originals, and photos with write errors are skipped and reported. Undo Last Batch restores the prior grade only when the saved target still matches the applied grade; subsequent edits are not overwritten. Its versioned manifest is saved in `~/Library/Application Support/FilmLab/BatchHistory.json`, so the undo control survives app restart. Backup files remain for manual recovery. A copied grade also stays in app memory until quit so clipboard changes during import or selection do not discard it.

In the signed app, settings copied from a disposable JPEG at +1.15 EV were pasted onto two selected targets: a Sony ARW and a JPEG. Both path-keyed records saved +1.15 EV. The RAW retained linear decoding, highlight recovery, 5633.9 K camera white balance and tint 4.00; the rendered JPEG retained its rendered-input controls. Undo Last Batch restored 0 EV on both, including RAW Stock Amount 1.00 and JPEG Stock Amount 0.70. The test establishes multi-photo transfer and restoration, not a calibrated color match or equal rendering across RAW and JPEG input.

After a rebuild, the signed app copied the same JPEG grade, copied an exposure-field value onto the macOS clipboard, and still pasted the in-app grade onto both disposable targets. The batch manifest recorded two 0-to-1.15 EV changes. After quitting and reopening FilmLab, Undo Last Batch was present and restored both targets to 0 EV; the manifest then held no pending changes. The RAW retained linear decode mode. This verifies restart-safe batch undo and clipboard-independent in-app copy for this local workflow.

## Deterministic color timing (2026-09-25)

New shadow, midtone, and highlight color timing now derives its hue direction from a mathematical HSV wheel rather than macOS `NSColor` conversion. The latter gave device-dependent RGB vectors, so replacing it for existing grades could shift an edited image. Edit records therefore carry a color timing version: older records without the field retain the prior vector path, while new photos and Reset Edits use the deterministic path. The Color workspace offers an explicit, undoable upgrade for older grades. This changes only tonal color timing, and a nonzero tonal strength can look different after upgrading. Existing legacy grades remain device-dependent until upgraded. Neither path is a measured film dye or spectral response.

The rendering probe checks red, green, and blue directions, hue wraparound, luminance preservation, and the legacy path. The signed app opened disposable Sony JPEG and ARW copies with legacy edit records, displayed the upgrade in Color, and restored the earlier version through Undo on each. Their saved records remained at version 1 with zero midtone strength after the test. This checks the compatibility action and local render path; it does not establish color consistency across multiple Macs or calibrated stock accuracy.

## Library search and sorting (2026-09-25)

The Library grid can search the selected catalog by filename and sort visible photos by import order, reverse import order, or name. This is a view operation; it does not reorder the saved catalog or alter per-photo edits. Select All adds the visible search results to the current selection. In the signed app, searching for “jpg” in a two-photo disposable catalog showed only the JPEG and Select All selected one photo. Clearing the search and choosing newest imported first displayed the JPEG before the ARW. Opening each again loaded its separate 0.70 and 1.00 stock amounts. Filename search does not inspect image metadata or file contents.

## Fit preview and export comparison (2026-09-25)

The optional real-image parity probe decodes a 2048 × 3072 center crop from a disposable RAW and JPEG, applies the same study-stock kernel at −2, 0, and +2 EV, and renders a half-size Fit preview, a 16-bit sRGB TIFF, and a JPEG. It compares 1024 × 1536 display-sRGB pixels after downsampling the exports. On the Sony copies, mean absolute channel differences from preview were 0.04–0.53 levels for TIFF and 0.54–1.23 levels for JPEG out of 255. Individual high-contrast pixels differed by up to 59 levels at +2 EV, so this is a whole-image drift check, not pixel-exact parity. Differences include the preview's half-float working buffer, resampling order, and JPEG compression. This probe uses the study stock and center crops, not the complete editor graph with every enabled control or all image formats. The signed app separately reopened both disposable photos with their distinct grades.

## Library favorites (2026-09-25)

The Library grid can mark a photo as a favorite and filter the selected catalog to favorites; filename search and sort still apply. Marks are keyed by local path in the saved library index and shared across catalogs. The decoder defaults a missing favorites field to empty so earlier library files continue to load. Relinking transfers a favorite, while removing the final reference clears it. The isolated library probe checks persistence, old-index decoding, shared references, relink, and removal. In the signed app, the disposable Sony ARW was marked and became the only visible photo under the Favorites filter; the mark survived relaunch. The JPEG and ARW still reopened at their separate 0.70 and 1.00 stock amounts. The test mark was removed afterward. This changes library organization, not image pixels or film-stock accuracy.

## Batch export (2026-09-25)

Library selection now offers JPEG, 16-bit sRGB TIFF, and 16-bit Display P3 TIFF export to a chosen folder. Each selected path is decoded with its saved RAW or rendered-input settings and passed through the same `PhotoEditor` development graph in a separate worker, leaving the open photo and its undo history in place. Current edits are flushed first; if that save fails, the open photo is skipped. Missing sources and edit records that need review are skipped with a summary. The export can be cancelled between photos. The output name helper appends a numeric suffix when a name is already present, including collisions between RAW and JPEG files with the same stem.

In the signed app, selecting a disposable Sony ARW and JPEG and exporting to a temporary folder produced two full-size 4672 × 7008 JPEGs, `Target-FilmLab.jpg` and `Target-FilmLab-2.jpg`. A repeated batch produced `-3` and `-4` outputs while the first files remained. The final signed build exported both photos again as 4672 × 7008 sRGB TIFFs with 16 bits per sample. SHA-256 hashes of both source copies were unchanged after export. The exporter probe checks filename selection, metadata, TIFF replacement behavior, and source-path protection. This verifies batch JPEG and sRGB TIFF output for these files; the batch Display P3 UI path, cancellation timing, and inaccessible originals have not been exercised in the signed app. It does not validate film-stock accuracy.

## Adjacent photo editing (2026-09-25)

The editor toolbar now has Previous Photo and Next Photo controls with Command–Option–Left/Right shortcuts. They walk the selected catalog's import order, skip missing originals, and stop at either end. The strip uses a scroll reader to bring the active thumbnail into view when the photo changes. In the signed app, the keyboard shortcuts moved from a disposable Sony RAW to its JPEG and back while the Shot Exposure field had focus; each photo loaded its separate 1.00 and 0.70 Stock Amount. The buttons disabled at the corresponding catalog ends. The auto-scroll behavior is implemented but has not been visually assessed with a strip wider than the window. This workflow change does not affect the stock model or its accuracy limits.

## Workspace resets (2026-09-25)

Each editor workspace now has an undoable reset control that clears its own adjustments while retaining edits in other workspaces. Develop returns RAW decoding to the linear mode and camera white balance; JPEG input corrections return to their defaults. Color reset leaves the saved color timing version intact, so older grades change versions only through the explicit upgrade action. The reset control is disabled when its workspace already matches defaults.

The signed app opened disposable Sony RAW and JPEG copies. On RAW, resetting Film cleared +1.00 Shot Exposure while leaving +0.50 Develop Output Exposure; Undo restored the Film value. Resetting Develop then returned its output exposure to zero and retained camera white balance around 5634 K and tint 4.00. On JPEG, resetting Texture cleared +0.50 Grain while leaving +0.30 Color Vibrance; Undo restored Grain. After restoring the test edits to zero, both saved records retained legacy color timing version 1. In the rebuilt app, Reset Color was disabled for an otherwise unchanged legacy JPEG while its separate upgrade remained available. These checks cover interaction and persistence on the two test files, not every control combination or film-stock accuracy.

## Selective workspace transfer (2026-09-25)

Settings now copies and pastes the active editor workspace between photos without replacing the other workspaces. The Develop paste follows the full-settings transfer rule for input controls: the destination retains its RAW decoder mode, highlight recovery, white balance, and rendered-input corrections. Color paste carries the source color timing version with the copied tonal grade. Workspace copies are held in app memory and are not portable look files.

The signed app copied a disposable Sony RAW Film workspace at +1.00 Shot Exposure and 1.00 Stock Amount onto its JPEG; the JPEG kept +0.50 Develop Output Exposure. A JPEG Develop workspace at +0.50 Output Exposure and 1.20 Input Tone was then pasted onto the RAW. The RAW kept linear decoding and its camera white balance, and a second run with a custom 6500 K RAW white balance preserved 6500 K while applying +0.50 Output Exposure. The test grades were reset to their prior defaults, and saved RAW/JPEG records again showed zero output and shot exposure with respective 1.00/0.70 Stock Amount. These checks establish transfer boundaries for the tested controls, not stock calibration or every possible adjustment combination.

## Batch workspace paste (2026-09-25)

Library selection can paste the copied workspace to multiple photos. It uses the same per-target recovery checks, pre-change backups, and persistent Undo Last Batch manifest as full-grade batch paste. The operation skips the currently open source photo. Only the copied workspace changes; Develop keeps each target's RAW decoder and white-balance or rendered-input settings.

In the signed app, a JPEG source at +0.80 Shot Exposure supplied its Film workspace to a selected Sony RAW and a second disposable JPEG. The batch reported two applied photos. The persisted manifest recorded both targets changing from zero to +0.80 Shot Exposure; the RAW kept linear decoding and camera white balance, while its Stock Amount followed the copied Film workspace from 1.00 to 0.70. After app restart, Undo Last Batch restored both targets and cleared the manifest. The RAW reopened at zero Shot Exposure and 1.00 Stock Amount. The source's test exposure was reset, and the extra JPEG reference was removed from the catalog. This verifies a two-target Film transfer and restart-safe undo, not every workspace combination or film-stock accuracy.

## Float preview (2026-09-25)

Preview rendering now offers an optional 32-bit float working context alongside the faster half-float default. The toggle is a global app preference, survives relaunch, and applies to Fit and 100% previews, comparison images, and preview diagnostics. Export already uses a 32-bit float working context. Final on-screen previews still convert to sRGB display pixels, so the option improves consistency of intermediate calculations rather than increasing monitor bit depth or source detail.

The synthetic preview probe rendered both modes, checked the float mode's comparison image and histogram, and found zero 8-bit channel difference between either full-size preview and a 16-bit sRGB TIFF of the same 64 × 64 gradient. The existing real-image probe passed for disposable Sony RAW and JPEG at −2, 0, and +2 EV in the default half-float mode; it does not establish exact parity for the full editor graph. In the signed app, the JPEG and RAW opened and rendered with Float preview enabled. A full-size 4672 × 7008 RAW view displayed, and the preference remained enabled after relaunch. Float full-size views use more memory and may render more slowly. The film-stock models remain uncalibrated.

## Per-photo grain patterns (2026-09-25)

New photo edit records now save a 24-bit grain seed derived from the source file's stable local identity. The Metal grain hash combines this seed with pixel coordinates so different photos do not repeat exactly the same noise field. Preview, export, and relaunch use the same saved seed. Copied looks and workspace settings preserve the target photo's seed. Earlier records without the field decode to zero, which leaves their previous grain pattern unchanged; Texture offers an undoable **Use unique grain pattern** action, and Reset Edits adopts the new pattern. Grain strength and size remain independent controls.

The rendering probe checks that equal seeds repeat, different seeds produce different output, legacy zero keeps the old deterministic result, and seeded half-float preview agrees with float export within its existing tolerance. The file-identity probe checks seed stability after rename and separation after copy. In the signed app, a legacy Sony RAW exposed the upgrade action; applying it saved seed 4761066 and Undo restored the old behavior. Fresh disposable RAW and JPEG copies received distinct seeds 12030632 and 1946850, rendered with Grain at 0.40, and restored that strength after relaunch. Their test strengths were reset to zero and their catalog references removed. This improves texture variation between photos; the grain distribution remains a provisional visual model without measured film scans.

## Library range selection (2026-09-25)

The Library now selects a contiguous range in its current visible order. Clicking a photo establishes the anchor; Shift-clicking another selects the photos between them and enters selection mode. The same operation is available from a photo's context menu as **Select Range Through This Photo**. Search, favorites, and sorting define which photos are visible and their order; if an anchor is hidden by a filter, the clicked target becomes the new anchor. Leaving selection mode or changing catalogs clears the anchor and selection.

The library probe checks forward and reverse ranges, hidden anchors, and a target absent from the visible list. In the signed app, a disposable Sony RAW and two JPEG entries appeared in import order. Opening the RAW established the first anchor; choosing the context action on the last JPEG selected all three and showed **Paste to 3 Photos**. Selection was cleared and the extra test reference removed, leaving the original two-photo catalog. The Shift-click modifier path uses the same range helper, but a physical Shift-click has not been exercised by the UI automation. This changes library navigation and does not affect image rendering or stock accuracy.

## Edited library thumbnails (2026-09-25)

Library tiles and the editor filmstrip now show a 320-pixel rendering of each photo's saved grade, using the same decoder and development graph as batch export. The current photo uses its live preview until it is closed or another photo opens. An original ImageIO thumbnail appears first while the edited rendering is prepared asynchronously; a bounded cache avoids repeating work during the session. Switching photos or pasting and undoing a batch invalidates affected thumbnails. If a saved record needs recovery, the tile falls back to the original thumbnail and does not write to the record.

In the signed app, a disposable Sony JPEG was set to +2.00 EV and then left by opening the RAW. Its Library tile was visibly brighter than the RAW tile. Returning the JPEG to 0.00 EV and opening the RAW restored the JPEG tile to its earlier appearance. These are visual checks of the tile refresh and saved-grade path; they do not quantify color parity or stock accuracy. A large catalog may take time to finish rendering its visible RAW thumbnails, and previews are display-sized sRGB images.

## Full-editor preview/export parity (2026-09-25)

The `FilmLabTests` target now opens disposable RAW and JPEG copies through `PhotoEditor`, applies an active Ektar/Premier paper study with input correction, local exposure, color grading, texture, output shoulder, and rotated square crop, then compares a float Fit preview with a saved 16-bit sRGB TIFF from batch export. The test uses the application's complete development graph and cleans up its temporary photos and saved edit records. It requires `FILMLAB_TEST_RAW` and `FILMLAB_TEST_JPEG`; without them it skips.

The first run found mean 8-bit channel differences of 2.49 (RAW) and 2.59 (JPEG). Isolating framing showed that cropped images retained a nonzero image origin, which caused extra preview/export sampling drift. Normalizing the framed image to a zero origin reduced differences to 1.12 and 1.44 respectively with the expanded graph. The largest individual differences were 66 and 95 levels, concentrated around high-contrast and texture edges. In the rebuilt signed app, both disposable Sony files displayed a rotated square crop and returned to their original framing with Reset Framing; the RAW and JPEG retained their separate grades. This is a whole-image consistency check under one grade and crop, not pixel-exact output equality or measured film-stock accuracy.

## Bounded thumbnail rendering (2026-09-25)

The Library now shares in-flight edited thumbnail requests by photo path and refresh token, with at most two full photo developments active at once. When a tile disappears or its grade changes, its waiting request is cancelled; the shared render stops when no tile still needs it. The active photo uses the already developed preview and does not start a duplicate thumbnail render. The first ImageIO source thumbnail still appears while a saved-grade render is queued. Bounded cached results continue to refresh when a photo is left, batch settings are pasted, or batch paste is undone.

Queue tests check duplicate sharing, the two-job limit, cancellation of a pending job, and cancellation of one of two waiters for the same job. In the rebuilt signed app, both disposable Sony RAW and JPEG thumbnails appeared in the Library. Applying +1.00 EV to the active RAW updated its tile; restoring 0.00 EV and opening the JPEG returned the RAW tile to its prior appearance. The two photos still loaded their separate 1.00 and 0.70 stock amounts. The tests cover scheduling behavior; actual RAW decode and GPU render work can still take time to observe cancellation. The grid and filmstrip retain 320-pixel display thumbnails and do not replace full-resolution export inspection.

## Tonal range for local areas (2026-09-25)

Each radial, linear, or painted local area can now multiply its spatial mask by a luminance selection. Center and width are measured in stops relative to 18% linear gray, with an adjustable soft edge. The selection samples the working image after input correction and preceding local areas, before the current adjustment and film response. It is saved in the area's edit record and carried through copied settings and looks. Older area records decode with the tonal limit off. Show mask displays the combined spatial and luminance selection. If the kernel cannot load, FilmLab skips the local adjustment rather than applying it to the whole area.

The synthetic probe placed deep shadow, middle gray, and bright highlight pixels inside the same radial geometry. A middle-gray tonal selection brightened only the middle pixel, and a legacy area decoded with the limit off. The full-editor RAW/JPEG parity test used the new selection, confirmed its saved fields, and passed against 16-bit TIFF export. In the signed app, both disposable Sony RAW and JPEG displayed a highlight-limited mask over the sky and bright rock while leaving the climber dark. A +1.00 EV JPEG adjustment and −0.50 EV RAW adjustment rendered; Reset Local restored each photo's prior local defaults. JPEG brightness reflects its baked camera rendering, so the same stop range does not imply the same scene exposure or recover clipped detail. This is an editing control, not a calibrated stock property.

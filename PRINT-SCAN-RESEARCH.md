# FilmLab: print, scan, color, and grain evidence

Reviewed 28 September 2026. This note follows `STOCK-RESEARCH.md` and `FILM-STOCK-SOURCES.md`. It asks which parts of a finished film image can be constrained without possessing a film roll. Links are to manufacturer publications or original research; examples and interpretations are identified separately. The research is sufficient to improve a physically structured *study*, not to certify a color match to a particular film scan or print.

## A reference output must be chosen

A negative has no single final RGB appearance. Kodak's [Basic Photographic Sensitometry Workbook, H-740](https://www.kodak.com/content/products-brochures/Film/Basic-Photographic-Sensitometry-Workbook.pdf) defines the negative density/exposure curve and explains why a higher-slope paper stage is used after a low-slope negative. Kodak's [Digital LAD calibration guide, H-387](https://www.kodak.com/content/products-brochures/Film/Users-Guide-and-Digital-Recorder-Calibration-and-Aims-H-387.pdf), page 1 and Tables II–VII, explicitly distinguishes Status M density from *printing density*, the latter being what a specific printer light/print-film combination sees. Its numerical conversion tables are for named **motion-picture intermediate and camera films**, not Portra, Gold, Ektar, or Endura. Copying them into FilmLab's still-film profiles would be unjustified.

**Decision for FilmLab:** identify the positive target as either (a) a virtual optical print on a named paper under specified illumination and processing, (b) a virtual, neutrally balanced scan, or (c) a creative grade. Do not describe one target's RGB output as the unique intrinsic look of the negative stock. Store the output choice separately from the stock and preserve it through copy/paste and catalog edits.

## Kodak Endura Premier: more data than the RGB curve alone

Kodak's [Endura Premier technical data, E-4070](https://business.kodakmoments.com/sites/default/files/files/resources/paper-endura-techpub-e4070.pdf) provides:

- Page 4: Status A red, green, and blue paper-density curves against log paper exposure, plus spectral sensitivity of its three dye-forming layers. FilmLab already uses an approximate digitization of the first graph in `Research/endura-premier-paper-tone.csv`.
- Page 5: spectral density curves for the paper's yellow, magenta, and cyan dyes. These can constrain a more physical reflectance model than independent `10^-D` display-RGB channels. The curves are printed graphs, not downloadable full-resolution measurements.
- Pages 1–3: RA-4 processing, optical enlarger light-source guidance (tungsten or tungsten-halogen), starting filtration of 40M + 50Y for a test print, and typical tricolor exposure times *for a specified enlarger and an 8× Portra negative*. These are setup examples, not a universal calibrated balance for every negative.
- Page 3: print evaluation around 5000 K (±1000 K), color-rendering index 85–100, and at least 538 lux. A spectral simulation still needs a particular viewing illuminant and white point.
- Page 2: digital output requires printer recalibration and output ICC profiles. Kodak's [CIS-289 calibration routines](https://business.kodakmoments.com/sites/default/files/files/products/paper-endura-calibration-cis289_0.pdf) list *different* procedures and values for different printers, and some profiles are supplied by the printer manufacturer. An Endura ICC profile, even if found, would characterize a specific printer/paper/process path rather than the film stock alone.

**Implemented study:** the [optical Premier route](Research/endura-premier-optical-print.md) uses approximate E-4070 spectral sensitivity and dye-density samples, Kodak paper characteristic curves, a declared tungsten source, RA-4 condition, and D50 viewing reference. Filtration is relative paper-layer attenuation because Kodak does not publish the exact filter spectra in this sheet. The graph readings and inferred negative decomposition remain provisional.

## Negative color response: still underdetermined

The [Portra 400 E-4050](https://kodakprofessional.com/sites/default/files/wysiwyg/pro/resources/e4050_portra_400.pdf), [Gold 200 E-7022](https://www.kodakprofessional.com/sites/default/files/wysiwyg/pro/resources/E7022%20Gold%20tech%20sheet.pdf), and [Ektar 100 E-4046](https://www.kodakprofessional.com/sites/default/files/2025-07/e4046.pdf) sheets publish characteristic curves, broad spectral sensitivity, and spectral dye-density examples. They do not publish a full dye spectrum at each exposure and color, a complete layer-interaction model, or a camera-specific scene-spectra reconstruction. The graphs are enough to make exposure follow a stock's toe and slope, but cannot uniquely determine the RGB values of a final print.

A public implementation of a more complete spectral negative-to-print-to-scan architecture is [spektrafilm](https://github.com/andreavolpato/spektrafilm), whose author also says the published diffuse dye data and coupler behavior need assumptions. It is architectural evidence, not a Kodak measurement. Its code is GPLv3 and profile data have separate CC BY-SA terms; FilmLab should derive its own model and not copy implementation or profile data without a licensing decision.

**Next usable work:** fit approximate spectral layer and dye functions to *each stock's own* published graphs, with provenance and fit error. Hold the paper model independent. This is more defensible than fixed color gains, but remaining degrees of freedom should be labeled provisional.

## Black-and-white print path

Kodak's Tri-X and T-Max sheets constrain the negative, not FilmLab's virtual positive. As a publicly documented paper target, Ilford's [Multigrade FB Classic technical sheet](https://www.ilfordphoto.com/amfile/file/download/file/1748/product/735/) gives density-versus-log-exposure curves for grades 00–5 under named filter/developer/time conditions. This could support an optional *Ilford paper* output for Kodak B&W negatives. It would be a deliberate cross-brand negative/paper pairing, not a measurement of a Kodak-specified print or scan. The paper grade changes the response curve itself, so a grade selector should use separate curves rather than a final-output contrast slider.

## Grain and sharpness

Kodak's Gold sheet reports a **Print Grain Index** under a specified negative size, print size, illumination, and viewing distance; its sheet says that index is on a different scale from RMS granularity. Tri-X and T-Max sheets report **diffuse RMS granularity** under named developers and a 48 µm aperture. Neither type yields a unique digital grain amplitude, grain correlation spectrum, dye-layer covariance, or scanner blur. FilmLab's current density-stage grain is therefore procedural texture, not a measurement-calibrated stock signature.

Newson et al.'s original [*Realistic Film Grain Rendering* paper and reference implementation](https://www.ipol.im/pub/art/2017/192/) offer a stochastic-grain method that can be rendered at different resolutions. This is a useful algorithmic direction for size-stable grain, but it does not supply calibrated Kodak stock parameters; the accompanying source code is GPL-3.0-or-later. Kodak stock datasheets also include modulation-transfer plots that can constrain a *target sharpness envelope*, but scanner optics, enlargement, and output sampling must be chosen before translating cycles/mm into a pixel-domain filter.

**Next usable work:** preserve grain in negative density, tie its physical scale to an explicit simulated 35 mm or 120 frame size and output dimensions, then compare its autocorrelation/power spectrum at multiple zoom levels. Treat stock-specific amplitude and scanner MTF as tunable studies until suitable native-resolution material is available.

## Public image references and what they prove

The authors of [*CNNs for Style Transfer of Digital to Film Photography*](https://arxiv.org/abs/2411.15967) publish an [aligned digital/CineStill 800T project and dataset link](https://github.com/cs-413-cinestill/800t-emulation). It can help test a comparison method, but its stock, camera, processing, and output do not calibrate Kodak Portra, Gold, Ektar, Tri-X, or T-Max. The repository page does not state a dataset reuse license; obtain the applicable terms before importing images into FilmLab's repository or distributing them.

A targeted search in September 2026 did **not locate** a downloadable, clearly licensed, same-scene digital-RAW/Kodak-film set with fixed scan settings and several exposure stops for these five stocks. This is a bounded search result, not proof that such data do not exist. Public sample scans are valuable for qualitative review if the stock and lab workflow are known, but automatic scanner color/tone adjustment can hide the original negative's exposure behavior.

## Priority after the optical-print study

1. Improve the stock-specific camera-to-negative layer sensitivity approximation using the manufacturer spectral plots. A digital RGB file cannot uniquely reconstruct the original scene spectrum, so keep the chosen reconstruction explicit.
2. Compare the positive output against legally usable public print or scan examples across lighting and exposure, accounting for unknown scan processing.
3. Characterize output texture and sharpness in physical image coordinates without converting Kodak's single grain numbers into arbitrary pixel variance.
4. Keep exact stock-matching claims reserved for independently characterized scans or prints with known processing and permission to use them.

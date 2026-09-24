# Published film data for FilmLab

## First reference: Kodak Professional Portra 400

Primary source: Kodak Alaris, *KODAK PROFESSIONAL PORTRA 400 Film*, publication E-4050, revised February 2016, https://imaging.kodakalaris.com/sites/default/files/files/resources/e4050_portra_400.pdf (four pages). The source was inspected visually, especially the four plots on page 4. Kodak's *Basic Photographic Sensitometry Workbook*, https://www.kodak.com/content/products-brochures/Film/Basic-Photographic-Sensitometry-Workbook.pdf, explains how negative density and the colored layers should be read.

### Direct observations

- The characteristic plot is **negative density versus log exposure (lux-seconds)**, measured in daylight using Status M densitometry. It labels a reference log H of **-1.44** and separately plots blue, green and red density.
- Within the published graph (approximately -3.4 to +0.6 log H), all three channels rise from a toe into a long, nearly straight region. The blue density slope is visibly steeper than green and red in the straight region. The chart does **not show a clear upper shoulder**. Its rightmost plotted exposure is about 2.0 log units, or about 6.8 stops, above the labeled -1.44 reference. That is a reading of graph bounds, not a claimed usable dynamic-range specification.
- The blue and green density curves sit above red because the processed negative has an orange mask. Their absolute offsets are not positive-image color casts. The workbook explains that the curves are read through blue, green and red densitometer filters and must be interpreted as dye-image densities.
- Kodak gives a numeric red-filter density of **0.77 to 0.87** for its gray card at normal exposure, on page 3. This is a useful independent sanity check, but the plotted Log H reference is not explicitly identified as the exposure of that gray-card measurement.
- The spectral-sensitivity graph gives broad, overlapping responses for the yellow-, magenta- and cyan-forming layers. The spectral-dye-density graph supplies a midscale neutral and minimum-density spectrum, but not a complete set of separately measured dye spectra across every exposure.
- The datasheet reports Print Grain Index values of 37, 59 and 89 for 35 mm negatives printed at 4×6, 8×10 and 16×20 inches. Kodak explicitly says this scale is not directly comparable to RMS granularity; it does not give FilmLab a pixel-grain amplitude.

### Consequences for FilmLab

The current study stock has a strong display-facing shoulder beginning around +2 stops and different toe/shoulder parameters per RGB channel. Those choices should **not be presented as measured Portra 400 behavior**. The Kodak negative-density chart instead calls for a long, nearly linear density region, with any later compression explicitly attributed to a print/scanner/display rendering stage.

A faithful workflow needs three distinct models: (1) scene-linear light to film-layer exposures using spectral sensitivities, (2) film-layer exposure to processed-negative density using the characteristic curves, and (3) negative density to a positive print or scan. The manufacturer's sheet constrains the first two but does not fully specify the third. A digital RAW's three RGB values also cannot uniquely recover the original scene spectrum. FilmLab must document its spectral reconstruction and positive rendering assumptions.

### Next implementation step

Use the initial chart samples in `Research/portra400-density.csv` to implement a standalone density-evaluation stage and a **separate, clearly provisional positive-rendering stage**. Keep the existing study stock available while comparing both across the -2/0/+2 EV RAW grid. Do not call the resulting positive image an exact Portra 400 match without matched scans or a measured print/scanner transform.

## Source licensing boundary

The manufacturer document is a reference for measurements and descriptive facts. Other film-simulation repositories were reviewed for conceptual context only; FilmLab has not copied their code, profiles or LUTs. In particular, `spektrafilm` advertises GPLv3 code and separately licensed profile data, so importing either would require deliberate license review.

### Initial curve digitization

`Research/portra400-density.csv` contains nine approximate points sampled from the three plotted curves. The PDF's page 4 was rendered at 160 dpi (1360 × 1760 pixels); the plotted axes were read at x = 180 for log H -4, x = 590 for log H +1, y = 638 for density 0, and y = 228 for density 4. At each sampled x, the center of each dark curve stroke was converted with `density = (638 - pixel_y) / 102.5`. The points are graph readings, not laboratory measurements; treat their absolute values as approximate within roughly 0.03 density and 0.03 log-H units. They do not encode the dye spectra, print stage or a camera-to-film spectral transform.

FilmLab now joins adjacent graph readings with shape-preserving cubic Hermite interpolation (PCHIP). Its tangents are calculated from the neighboring sampled slopes and stored in the Metal kernel. This is a numerical smoothing choice: it preserves the sampled values and monotonic density response, but does not add measurements between samples. The response outside each plotted range remains a separate model assumption.

### RGB-to-layer approximation, 24 September 2026

Kodak's spectral-sensitivity plot shows broad blue-, green-, and red-sensitive bands with overlap. A three-channel camera file cannot uniquely determine the original scene spectrum, so FilmLab currently approximates layer exposure with a neutral-preserving RGB matrix before looking up negative density:

| Film-sensitive layer | Input R | Input G | Input B |
| --- | ---: | ---: | ---: |
| Red / cyan-forming | 0.94 | 0.06 | 0.00 |
| Green / magenta-forming | 0.10 | 0.82 | 0.08 |
| Blue / yellow-forming | 0.00 | 0.12 | 0.88 |

Each row sums to one, so a neutral scene patch stays neutral before the different density curves act. The coefficients are conservative modeling assumptions suggested by the plotted overlap, **not** values published or measured by Kodak. A future spectral reconstruction and film-layer integration should replace them. The print/scan stage is still provisional.

## Second reference: Kodak Professional Ektar 100

Primary source: Kodak, *KODAK PROFESSIONAL EKTAR 100 Film*, publication E-4046, January 2025, https://www.kodakprofessional.com/sites/default/files/2025-07/e4046.pdf. Page 4 plots daylight-exposed, Status M red, green and blue processed-negative density against log exposure. Its marked reference exposure is log H **-0.84**. Kodak calls the curves representative rather than specifications for a particular production batch.

`Research/ektar100-density.csv` records nine approximate readings from that chart. Page 4 was rendered at 180 dpi (1530 × 1980 pixels). The graph axes were read at x = 203 for log H -3, x = 571 for log H +1, y = 731 for density 0, and y = 269 for density 4. The centers of the colored curve strokes were sampled at log H -2.8, -2.5, -2, -1.5, -1, -0.5, 0, 0.5 and 1. Treat values as graph readings with roughly ±0.03 density and ±0.03 log-H uncertainty, not laboratory measurements. Shape-preserving cubic Hermite interpolation joins the samples; the response outside the plotted range holds the low-density end or extends the high-density slope as a modeling assumption.

FilmLab anchors scene-linear 0.18 gray to Kodak's marked -0.84 log H reference. This is a calibration choice, not an absolute lux-second measurement of the digital file. The RGB-to-layer overlap matrix and balanced positive print/scan transform used by the Portra study are reused for Ektar; **neither is a measured Ektar color transform**. Development adjustment is provisional. The Ektar source recommends Endura Premier paper. FilmLab offers a separate Endura Premier paper study for this stock; it does not apply the older Portra Endura curves to Ektar. Matched exposure-series scans and print or scanner characterization are still needed to claim a close color match.

## Optional paper tone reference: Kodak Professional Portra Endura

Kodak, *KODAK PROFESSIONAL PORTRA ENDURA Paper and KODAK PROFESSIONAL SUPRA ENDURA Paper*, publication E-4021, revised September 2009, https://125px.com/docs/paper/kodak/e4021-200909.pdf (Kodak-authored document hosted by a third-party archive). Page 7 plots paper density against log paper exposure after RA-4 processing, with separate Status A red, green and blue curves. The paper predates the 2010 Portra 400 emulsion; this is an illustrative print-paper pairing, not a documented calibrated film-paper combination.

`Research/endura-paper-tone.csv` contains approximate readings of the **red, green and blue** characteristic curves from the page-7 graph. The page was rendered at 180 dpi (1530 × 1980 pixels). The plot axes were read at x = 935 for log exposure -3, x = 1396 for 0, y = 677 for density 0 and y = 216 for density 3. The curves overlap heavily in the toe and middle; shared values there represent unresolved graph strokes, not proven equality. At higher paper exposure, the red and green curves reach about 2.6 density while blue levels near 2.4. All points are approximate; treat separations smaller than about 0.05 density as uncertain. These are graph readings, not laboratory or per-batch specifications. Kodak explicitly notes that the curves are representative rather than specifications for a particular box or roll.

For an optical-print approximation, higher negative density transmits less enlarger light: `log H_paper = balance - (D_negative - D_reference)`. FilmLab maps each paper exposure through the corresponding sampled Status A curve and maps paper density to relative reflectance with `10^-D`. The balance and neutral-gray aim remain choices; the sheet does not provide a complete enlarger spectrum, film-to-paper calibration, separate dye absorption at every density, viewing illumination or scanner appearance. The resulting RGB behavior is an **approximate color-paper response**, not a calibrated optical-print simulation.

## Optional paper tone reference: Kodak Professional Endura Premier

Primary source: Kodak, *KODAK PROFESSIONAL ENDURA Premier Paper*, publication E-4070, March 2013, https://business.kodakmoments.com/sites/default/files/files/resources/paper-endura-techpub-e4070.pdf. Page 4 plots Status A red, green and blue paper density against log paper exposure after RA-4 processing at 35°C for 45 seconds and a 0.5-second exposure. Kodak describes the curves as representative rather than specifications for an individual box or roll.

`Research/endura-premier-paper-tone.csv` contains approximate graph readings. The page was rendered at 220 dpi; the graph axes were read at x = 1114 for log H -3, x = 1678 for log H 0, y = 786 for density 0 and y = 222 for density 3. Red, green and blue strokes overlap in the toe and midrange, so their small differences are uncertain; allow at least ±0.05 density for these readings. These samples are neither lab measurements nor a complete spectral characterization. Shape-preserving cubic interpolation joins them without adding measured information between samples.

As in the Portra Endura study, negative density reduces assumed enlarger exposure, the sampled paper curve yields density, and `10^-D` yields relative reflectance. The Premier model assumes a -1.4 log-H paper balance and a neutral 0.75-density gray aim. Those are FilmLab choices, not Kodak calibration values. Paper Exposure and Paper Strength are creative controls. Enlarger light spectra, dye cross-talk, processing variation, viewing conditions and matched Ektar optical prints remain necessary for a defensible film-to-print color match.

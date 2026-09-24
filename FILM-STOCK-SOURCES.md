# Published film data for FilmLab

## First reference: Kodak Professional Portra 400

Primary source: Kodak Alaris, *KODAK PROFESSIONAL PORTRA 400 Film*, publication E-4050, revised February 2016, https://imaging.kodakalaris.com/sites/default/files/files/resources/e4050_portra_400.pdf (four pages). The source was inspected visually, especially the four plots on page 4. Kodak's *Basic Photographic Sensitometry Workbook*, https://www.kodak.com/content/products-brochures/Film/Basic-Photographic-Sensitometry-Workbook.pdf, explains how negative density and the colored layers should be read.

### Direct observations

- The characteristic plot is **negative density versus log exposure (lux-seconds)**, measured in daylight using Status M densitometry. It labels a reference log H of **-1.44** and separately plots blue, green and red density.
- Within the published graph (approximately -3.4 to +0.6 log H), all three channels rise from a toe into a long, nearly straight region. The chart does **not show a clear upper shoulder**. Its rightmost plotted exposure is about 2.0 log units, or about 6.8 stops, above the labeled -1.44 reference. That is a reading of graph bounds, not a claimed usable dynamic-range specification.
- The blue and green density curves sit above red because the processed negative has an orange mask. Their absolute offsets are not positive-image color casts. The workbook explains that the curves are read through blue, green and red densitometer filters and must be interpreted as dye-image densities.
- Kodak gives a numeric red-filter density of **0.77 to 0.87** for its gray card at normal exposure, on page 3. This is a useful calibration check for a digitized characteristic curve.
- The spectral-sensitivity graph gives broad, overlapping responses for the yellow-, magenta- and cyan-forming layers. The spectral-dye-density graph supplies a midscale neutral and minimum-density spectrum, but not a complete set of separately measured dye spectra across every exposure.
- The datasheet reports Print Grain Index values of 37, 59 and 89 for 35 mm negatives printed at 4×6, 8×10 and 16×20 inches. Kodak explicitly says this scale is not directly comparable to RMS granularity; it does not give FilmLab a pixel-grain amplitude.

### Consequences for FilmLab

The current study stock has a strong display-facing shoulder beginning around +2 stops and different toe/shoulder parameters per RGB channel. Those choices should **not be presented as measured Portra 400 behavior**. The Kodak negative-density chart instead calls for a long, nearly linear density region, with any later compression explicitly attributed to a print/scanner/display rendering stage.

A faithful workflow needs three distinct models: (1) scene-linear light to film-layer exposures using spectral sensitivities, (2) film-layer exposure to processed-negative density using the characteristic curves, and (3) negative density to a positive print or scan. The manufacturer's sheet constrains the first two but does not fully specify the third. A digital RAW's three RGB values also cannot uniquely recover the original scene spectrum. FilmLab must document its spectral reconstruction and positive rendering assumptions.

### Next implementation step

Digitize the three characteristic curves from the manufacturer's chart into versioned log-H/density samples, recording chart-coordinate error bounds and checking the red gray-card density against 0.77–0.87. Implement a standalone density-evaluation stage and a **separate, clearly provisional positive-rendering stage**. Keep the existing study stock available while comparing both across the -2/0/+2 EV RAW grid. Do not call the resulting positive image an exact Portra 400 match without matched scans or a measured print/scanner transform.

## Source licensing boundary

The manufacturer document is a reference for measurements and descriptive facts. Other film-simulation repositories were reviewed for conceptual context only; FilmLab has not copied their code, profiles or LUTs. In particular, `spektrafilm` advertises GPLv3 code and separately licensed profile data, so importing either would require deliberate license review.

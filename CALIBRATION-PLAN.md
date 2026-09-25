# FilmLab calibration boundary

FilmLab currently separates published negative-density measurements from its assumed camera-to-film and negative-to-positive transforms. Kodak's [Portra 400 E-4050](https://imaging.kodakalaris.com/sites/default/files/files/resources/e4050_portra_400.pdf) and [Ektar 100 E-4046](https://www.kodakprofessional.com/sites/default/files/2025-07/e4046.pdf) give characteristic, spectral-sensitivity and midscale dye-density plots. They do not specify one final positive image for every scanner, enlarger, paper and viewing condition. The app therefore labels both profiles as density studies.

A [published paired digital/film dataset](https://arxiv.org/abs/2411.15967) exists for CineStill 800T. It is useful evidence that matched captures can support validation, but it cannot calibrate Portra or Ektar. The current public search found exposure tests and styled scan examples for those Kodak stocks, but no downloadable, licensed set that includes the same scene as digital RAW and controlled film scans across exposure stops. That is a search result, not a claim that no such dataset exists.

## Reference set needed

- Capture the same static scene on digital RAW and each target stock at several exposures, with a gray card and color target in at least some frames. Record illuminant and camera settings.
- Develop the film under a documented process. Scan each negative with fixed scanner settings and retain high-bit-depth, minimally processed files plus the exact scan profile.
- Include daylight, shade, mixed light, skin, foliage and high-contrast scenes. Reserve entire scenes as holdouts.
- Fit the camera-to-layer mapping and positive print/scan transform only after the reference rendering condition is chosen. Keep Kodak's density samples as constraints, and test exposure response rather than one nominal-exposure appearance.
- Compare neutral balance, patch color error, highlight and shadow trajectories, clipping, and texture at native scale. Report results by scene and exposure; do not turn one attractive result into a stock-accuracy claim.

Until that set exists, FilmLab should improve its editing workflow and rendering reliability while clearly marking unmeasured color choices as provisional.

A September 2026 check also found [PoLUT's manufacturer-curve digitizations](https://github.com/TomPoczos/PoLUT) for Portra and Ektar. They offer another reading of published film and paper plots and describe a spectral reconstruction assumption, but do not supply paired digital RAW and controlled positive scans across exposure stops. FilmLab has not imported that project's code, LUTs, or data. The [CineStill 800T paired-image study](https://arxiv.org/abs/2411.15967) remains a useful validation-method example for a different stock; it does not establish Portra or Ektar color accuracy.

The negative-density curves now leave each published upper endpoint along the fitted endpoint tangent. This avoids a change in response slope at the edge of the plotted data, but the extrapolated values remain an engineering assumption. The published charts alone cannot establish highlight behavior beyond their final sampled exposure or the appearance of a finished scan or print.

The Endura and Endura Premier paper studies now continue beyond their final published sample with a bounded, slope-matched shoulder. It removes a response kink in extreme paper exposures; the shoulder width and asymptote are engineering assumptions. Existing edits that reach that region may render slightly darker. Matched print references are still needed before claiming paper accuracy.

New grades using the Portra or Ektar density studies can add spatial texture to the negative-density image before the provisional print/scan transform. This makes its visible amplitude depend on the stock curve, exposure, and paper response. Its noise spectrum, layer correlation, and density scale are engineering choices, not measurements of Kodak grain. Existing saved grades retain their prior output grain until explicitly upgraded in the Texture panel. The generic study stock still uses output grain.

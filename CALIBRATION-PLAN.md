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

The negative-density curves now leave each published upper endpoint along the fitted endpoint tangent. This avoids a change in response slope at the edge of the plotted data, but the extrapolated values remain an engineering assumption. The published charts alone cannot establish highlight behavior beyond their final sampled exposure or the appearance of a finished scan or print.

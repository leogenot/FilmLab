# Endura Premier optical-print study

Source: Kodak Professional ENDURA Premier Paper, technical publication E-4070, pages 4–5: https://business.kodakmoments.com/sites/default/files/files/resources/paper-endura-techpub-e4070.pdf

The opt-in Film panel mode uses the existing stock-specific negative density curves and E-4070's approximate Status A paper characteristic curves. An inferred, weakly coupled three-layer enlarger exposure maps negative density to paper exposure. The resulting cyan, magenta, and yellow densities are projected through visually sampled 400–700 nm dye spectra at 25 nm spacing, then integrated against the official CIE 1931 2° observer and D50 illuminant. A Bradford D50-to-D65 adaptation and linear-sRGB matrix convert the resulting XYZ values for FilmLab’s working space. The reference negative is balanced to a neutral 0.18 display value at zero paper exposure. Paper exposure is an actual shift in log exposure before the nonlinear paper curves; shot exposure remains upstream of negative development and texture.

## Boundaries

- E-4070 plots describe photographic paper; they do not provide the full spectral transmission of each Portra, Ektar, or Gold negative at every exposure.
- The layer-coupling matrix, neutral enlarger balance, and mid-gray aim are inferred. Dye samples were read visually from a printed graph, so this is not a calibrated spectral measurement or a Kodak-approved print profile.
- The film grain stage remains upstream of the optical print. Physical enlarger flare, lens scatter, paper surface, chemical process variation, optical sharpness, and scanner behavior are not modeled.
- Existing virtual scan and per-channel paper responses remain the default for old edits. The new Codable flag defaults to false when absent and is copied with Film panel settings.

## Colorimetry sources

- CIE 1931 2° colour-matching functions: https://cie.co.at/datatable/cie-1931-colour-matching-functions-2-degree-observer (CSV MD5 `17cca777db64b17170f06f67ce9d3ab7`).
- CIE standard illuminant D50: https://cie.co.at/datatable/cie-standard-illuminant-d50 (CSV MD5 `e72757c3078b58e78ba63051be4b27b0`).
- `cie-d50-print-integration.csv` records every 25 nm input and normalized integration weight. Endpoints use trapezoidal half weights. This 400–700 nm approximation truncates the tails of both the observer and illumination functions.
- Chromatic adaptation follows the Bradford method described by the International Color Consortium: https://www.color.org/chadtag/. The final conversion targets FilmLab’s extended linear-sRGB working space.
- Comparing 25 nm integration against 1 nm CIE/D50 integration of linearly interpolated paper dye samples gave at most 0.0057 absolute XYZ error over six representative dye mixtures. The darkest neutral mixture had an 8.8% relative Y difference, but only about 0.0012 absolute XYZ error. The underlying dye readings remain the larger uncertainty.

## Verification

`Scripts/build-app.sh` built and signed the app. `Scripts/verify-rendering.sh` passed with disposable `Target.ARW` and `Target.jpg` in `/private/tmp/FilmLab-batch-ui-probe`. The focused probe checks neutral reference, print darkening with increasing paper exposure, and print lightening with increasing shot exposure for all three color stocks. The signed app UI was opened on both disposable files; enabling the mode produced a rendered histogram and an updated paper control.

# Endura Premier optical-print study

Source: Kodak Professional ENDURA Premier Paper, technical publication E-4070, pages 4–5: https://business.kodakmoments.com/sites/default/files/files/resources/paper-endura-techpub-e4070.pdf

The opt-in Film panel mode uses the existing stock-specific negative density curves and E-4070's approximate Status A paper characteristic curves. An inferred, weakly coupled three-layer enlarger exposure maps negative density to paper exposure. The resulting cyan, magenta, and yellow densities are projected through visually sampled 400–700 nm dye spectra at 25 nm spacing, then integrated with provisional display-channel weights. The reference negative is balanced to a neutral 0.18 display value at zero paper exposure. Paper exposure is an actual shift in log exposure before the nonlinear paper curves; shot exposure remains upstream of negative development and texture.

## Boundaries

- E-4070 plots describe photographic paper; they do not provide the full spectral transmission of each Portra, Ektar, or Gold negative at every exposure.
- The layer-coupling matrix, display weights, neutral enlarger balance, and mid-gray aim are inferred. Dye samples were read visually from a printed graph, so this is not a calibrated spectral measurement or a Kodak-approved print profile.
- The film grain stage remains upstream of the optical print. Physical enlarger flare, lens scatter, paper surface, chemical process variation, optical sharpness, and scanner behavior are not modeled.
- Existing virtual scan and per-channel paper responses remain the default for old edits. The new Codable flag defaults to false when absent and is copied with Film panel settings.

## Verification

`Scripts/build-app.sh` built and signed the app. `Scripts/verify-rendering.sh` passed with disposable `Target.ARW` and `Target.jpg` in `/private/tmp/FilmLab-batch-ui-probe`. The focused probe checks neutral reference, print darkening with increasing paper exposure, and print lightening with increasing shot exposure for all three color stocks. The signed app UI was opened on both disposable files; enabling the mode produced a rendered histogram and an updated paper control.

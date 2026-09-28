# Color-negative layer sensitivity: public-data study

Reviewed 28 September 2026. This note defines a reproducible **interpretation** of Kodak's published spectral-sensitivity plots for Portra 400, Ektar 100, and Gold 200. It does not recover a scene spectrum from a camera RGB pixel or establish an exact Kodak color match.

## Primary sources and meaning

- Kodak Alaris, [*KODAK PROFESSIONAL PORTRA 400 Film*, E-4050](https://www.kodakprofessional.com/sites/default/files/2025-07/e4050.pdf), page 4, spectral-sensitivity figure E4040P.
- Kodak Alaris, [*KODAK PROFESSIONAL EKTAR 100 Film*, E-4046](https://www.kodakprofessional.com/sites/default/files/2025-07/e4046.pdf), page 4, figure E4046B.
- Kodak Alaris, [*KODAK GOLD 200 Film*, E-7022, June 2023](https://www.kodakprofessional.com/sites/default/files/wysiwyg/pro/resources/E7022%20Gold%20tech%20sheet.pdf), page 4, figure E7022C.
- Brian Smits, [*An RGB-to-Spectrum Conversion for Reflectances*](https://doi.org/10.1080/10867651.1999.10487511), *Journal of Graphics Tools* 4(4), 1999. This is a practical choice of one plausible spectrum among many RGB metamers, not a physical inversion. The [author's code archive](https://github.com/colour-science/smits1999) is available for cross-checking.

Each Kodak x-axis is **wavelength, nm**, approximately 250–750. The y-axis is **log sensitivity**, not a relative transmission or dye-density curve. The footnote defines sensitivity as reciprocal radiant exposure in erg/cm² needed to produce **Status M density 0.2 above D-min**. Curves are labeled by the **dye-forming layer**: yellow is principally blue-sensitive, magenta green-sensitive, cyan red-sensitive. Portra and Gold state 1/50-second effective daylight exposure; Ektar states 1/25 second. These are one test condition; do not reinterpret the vertical offset as an arbitrary RGB channel gain. The separate characteristic charts label B/G/R **densitometer filters** and do not define the input-layer weighting.

## Approximate graph readings

The following log-sensitivity values were visually sampled from the plotted stroke centers at 25 nm intervals. The source PDF pages were rendered at 1870 × 2420 pixels and the lower-left graphs enlarged for reading. `—` means the stroke is not drawn at that wavelength; use zero linear sensitivity outside the drawn support, with a short taper at an endpoint rather than extending the final log value. The plot lines and embedded labels overlap. Allow about **±0.15 log unit** in clear regions, **±0.25–0.35** at crossings, tails, or labels. Wavelength position is uncertain by roughly **±5 nm**. The short secondary blue-side strokes belong to the longer green-sensitive curve where continuous; the red-sensitive curve has a weak green-side tail. These readings are suitable for a smooth, explicitly approximate computation, not precision sensitometry.

| nm | Portra Y | Portra M | Portra C | Ektar Y | Ektar M | Ektar C | Gold Y | Gold M | Gold C |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 375 | 1.8 | — | — | 1.1 | — | — | 0.8 | — | — |
| 400 | 2.6 | 1.5 | — | 2.0 | 0.9 | — | 2.1 | 1.2 | 0.4 |
| 425 | 2.55 | 1.4 | — | 2.05 | 0.7 | — | 2.1 | 1.1 | 0.1 |
| 450 | 2.5 | 1.3 | — | 2.1 | 0.55 | — | 2.15 | 0.95 | — |
| 475 | 2.6 | 1.4 | — | 2.15 | 0.55 | — | 2.3 | 0.95 | — |
| 500 | 1.25 | 2.0 | 0.4 | 0.3 | 1.25 | — | 0.0 | 1.55 | 0.1 |
| 525 | — | 2.25 | 0.75 | — | 1.55 | — | — | 1.9 | 0.4 |
| 550 | — | 2.55 | 0.75 | — | 1.8 | 0.2 | — | 2.25 | 0.65 |
| 575 | — | 2.25 | 1.3 | — | 1.55 | 0.4 | — | 1.65 | 1.0 |
| 600 | — | 0.7 | 2.0 | — | 0.3 | 1.55 | — | — | 1.55 |
| 625 | — | — | 2.35 | — | — | 1.75 | — | — | 1.9 |
| 650 | — | — | 2.65 | — | — | 2.05 | — | — | 2.25 |
| 675 | — | — | 1.2 | — | — | 1.0 | — | — | 1.0 |
| 700 | — | — | — | — | — | 0.3 | — | — | — |

The table should be independently re-digitized before treating small inter-stock differences as evidence. In particular, a ±0.15 log reading changes local linear sensitivity by a factor of about 1.4; that uncertainty exceeds many of the apparent fine undulations.

## Recommended camera-RGB-to-layer method

1. Start from **scene-linear working RGB**, with the camera/RAW profile applied and display transfer function removed for JPEG. Retain signed/high-range values through the rest of the image pipeline; any spectral reconstruction needs a documented handling rule for out-of-gamut or negative RGB. FilmLab currently receives extended-linear RGB, not scene spectral radiance.
2. Choose and version a single D65-relative RGB-to-spectral reconstruction rule. A Smits-style seven-basis reflectance reconstruction is a practical option; a smooth nonnegative basis fitted to the CIE 1931 observer under D65 is another. Scale the reconstructed spectrum by linear scene intensity for HDR values. Do **not** read the Kodak chart as if `R`, `G`, `B` display channels were narrow wavelength bins.
3. Convert each Kodak sample to linear sensitivity `S_i(λ) = 10 ** logS_i(λ)`. Integrate the reconstructed incident spectrum `E_RGB(λ)` against the chosen stock's layer sensitivity: `H_i = Σ E_RGB(λ) S_i(λ) Δλ`. For a reflectance reconstruction, the incident spectrum is `D65(λ) × R_RGB(λ)` under this **declared reference illuminant**. The resulting quantity is relative layer exposure; it is not calibrated erg/cm².
4. Independently normalize each layer by the integral for a unit neutral reflectance under the same D65 rule, `N_i = Σ D65(λ) S_i(λ) Δλ`. Use `layerLight_i = H_i/N_i`; a 0.18 neutral pixel then gives 0.18 at every layer. This forces neutral RGB to equal neutral layer light before the existing stock-specific log-H anchor. Shot exposure then multiplies **all** layer exposures by `2^EV` before the stock's own characteristic curves. Keep E-4050/E-4046/E-7022 chart anchors distinct.
5. If implementation needs a compact shader, pre-integrate **seven** selected spectral reconstruction bases against each of the three layer sensitivities at 25 nm or finer. The resulting 3×7 table plus Smits's piecewise RGB decomposition retains the non-linear gamut behavior of the chosen reconstruction. A 3×3 matrix is a faster approximation but cannot reproduce the same mapping for all RGB colors; fit it from the seven-basis model and test errors on neutral, saturated, and mixed colors before using it.

## Implemented model

FilmLab uses a *linear three-basis* spectral surrogate, not Smits's seven-basis model. For each wavelength, the three nonnegative basis weights in `stock-layer-sensitivity-source.csv` sum to one. They were fitted to the CIE 1931 XYZ values of linear-sRGB primaries under D65, using smooth Gaussian starting bands centered at 650/540/440 nm, a simplex constraint at each wavelength, and a small adjacent-wavelength smoothness term. The 25 nm table reproduces each primary's normalized XYZ coordinates within 0.002. A neutral RGB value therefore reconstructs a constant D65-relative reflectance and every stock layer is normalized to that neutral. Because the surrogate is linear in RGB, its Kodak-layer integration is *exactly* representable as a stock-specific 3×3 matrix. It does not claim to approximate a nonlinear seven-basis reconstruction. The three-basis choice is computationally compact and explicit about the particular metamer it selects; a future seven-basis model would require a new saved-grade version.

`generate-stock-layer-sensitivity.py` is the source-to-shader step and `--check` is part of rendering verification. Blank log-sensitivity cells are zero linear sensitivity, and trapezoidal endpoint weights are used at 400 and 700 nm. There is no ultraviolet contribution below 400 nm in this RGB model. The D65 entries come from [CIE standard illuminant D65](https://www.cie.co.at/datatable/cie-standard-illuminant-d65), with the published CSV MD5 `03d4eb9b837c60671627c946fb534deb`. The observer entries come from [CIE 1931 2° colour matching functions](https://cie.co.at/datatable/cie-1931-colour-matching-functions-2-degree-observer). Existing grades retain the older shared matrix; new grades use the generated stock-specific coefficients. A legacy grade can opt into the new response from the Film panel.

For the versioned change, validate `RGB=(t,t,t)` over shadow, midtone, and HDR input: every layer receives the same *relative* exposure `t`, and a +1 EV shift increases each by 2×. Test stock differences on saturated and mixed colors, preserving monotonic light response. Check output under daylight-like and tungsten-like photographed scenes, but do not relight a white-balanced RAW using an invented illuminant spectrum.

## Limits that should remain visible in product and research notes

Three camera RGB numbers do not uniquely determine the photographed spectrum. Two spectra that match to the camera or human observer can expose film layers differently. Camera spectral sensitivities, RAW white-balance multipliers, display/working RGB conversion, and original scene illuminant may be unknown after editing. Kodak's charts give a sensitivity threshold, not every layer's complete exposure/development interaction or full dye spectra. Thus any recovered film-layer response is an assumed metamer selected by the reconstruction rule. Preserve the label **stock study** and document the algorithm and source readings; do not describe a particular stock output as physically calibrated.

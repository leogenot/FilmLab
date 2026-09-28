# Film stock research: Gold 200, Tri-X 400, T-Max 100

Reviewed 28 September 2026. These are manufacturer publications, not matched digital/film capture data. The characteristic plots constrain a **processed negative**, while a final positive depends on printing or scanning. FilmLab must keep those stages separate and label any implementation a density study until matched reference scans validate it. Existing Portra 400 and Ektar 100 notes remain in `FILM-STOCK-SOURCES.md`.

## Kodak Gold 200: color negative

Source: Kodak Alaris, [*KODAK GOLD 200 Film*, E-7022, revised June 2023](https://www.kodakprofessional.com/sites/default/files/wysiwyg/pro/resources/E7022%20Gold%20tech%20sheet.pdf). See PDF pages 1, 3, and 4 (one-based). The older [February 2016 E-7022](https://www.kodakprofessional.com/sites/default/files/wysiwyg/pro/resources/E7022_Gold_200.pdf) has the same graph labeling, but the readings below use the newer publication.

**Published observations.** ISO 200 in daylight or electronic flash; Kodak describes a latitude of two stops under to three stops over (page 1). The page-4 characteristic plot gives three **Status M negative-density versus log exposure** curves for daylight exposure, with marked reference log H **−1.14**. The blue-filter density curve sits above green, which sits above red. That ordering includes the color negative's dye/mask densities and is **not** a prescription for a blue positive image. The same page includes overlapping spectral-sensitivity bands for the cyan-, magenta-, and yellow-forming layers and two illustrative spectral-dye-density traces (midscale neutral and D-min); it does not supply separate full dye spectra for every density. Kodak says the sensitometric curves represent tested production coatings, not a specification for each roll. Page 3 gives a **Print Grain Index of 44** for a 24 × 36 mm negative enlarged to a 4 × 6 inch diffuse print, viewed at 14 inches. Kodak explicitly says this index is on a different scale from diffuse RMS granularity. Page 2 calls for **C-41/Flexicolor** processing and lists Endura Premier among printing papers; it does not establish a unique positive transform.

**Implementation consequence.** Digitize the three page-4 density curves (with graph-reading uncertainty recorded) and interpolate monotonically in log exposure. Apply Shot Exposure *before* each layer's density lookup. Keep FilmLab's RGB-to-layer approximation explicit and provisional, as for Portra/Ektar. A Gold 200 positive should use a separately identified print/scan choice; the published “warm/saturated” product description is not enough to set fixed RGB gains. Negative-density grain should be evaluated before that positive stage so its visible effect changes with exposure and the print response. Index 44 is a print-viewing comparison datum, not a pixel noise standard deviation.

**Initial graph readings.** Page 4 was rendered at 240 dpi (2040 × 2640 pixels). In the characteristic plot, x≈272 maps to log H −3, x≈887 to +1, y≈855 to density 0, and y≈240 to density 4. I visually sampled centers of the three strokes, rather than treating this as laboratory data. Allow roughly ±0.04 density and ±0.03 log-H, with larger uncertainty at the chart ends. `B/G/R` name the **densitometer filters**, not display RGB output channels.

| log H | Status M B density | G | R |
| ---: | ---: | ---: | ---: |
| −2.8 | 0.98 | 0.67 | 0.26 |
| −2.5 | 1.01 | 0.72 | 0.29 |
| −2.0 | 1.19 | 0.91 | 0.46 |
| −1.5 | 1.49 | 1.18 | 0.73 |
| −1.0 | 1.81 | 1.46 | 0.99 |
| −0.5 | 2.11 | 1.75 | 1.27 |
| 0.0 | 2.42 | 2.02 | 1.55 |
| +0.5 | 2.62 | 2.20 | 1.72 |
| +0.85 | 2.73 | 2.30 | 1.83 |

## Kodak Professional Tri-X 400 / 400TX: black-and-white negative

Source: Kodak Alaris, [*KODAK PROFESSIONAL TRI-X 320 and 400 Films*, F-4017, February 2016](https://www.kodakprofessional.com/sites/default/files/wysiwyg/pro/resources/f4017_TriX.pdf). For **400TX**, see PDF pages 1, 6, 7, and 8 (one-based); the separate 320TXP curves must not be reused.

**Published observations.** Tri-X 400 is panchromatic, available in 135 and 120, and Kodak recommends it for push processing (page 1). Page 7 plots spectral sensitivity and modulation transfer. Pages 7–8 plot **diffuse visual negative density versus log exposure** for 400TX in both 35 mm and 120, with several *distinct curves* for different development times. The page-8 D-76 large-tank plot shows 6, 8, 10, and 12 minutes at 20°C with agitation each minute; the page-7 T-MAX small-tank plot shows 6, 7, 9, and 11 minutes at 20°C with agitation every 30 seconds. These are different process families, not one stock curve plus an arbitrary global contrast multiplier. Page 8 also plots contrast index versus development time for multiple developers. Page 6 reports **diffuse RMS granularity 17**, measured at net diffuse density 1.0 with a 48 µm aperture and 12× magnification, for material developed in HC-110 dilution B at 20°C. This is not directly comparable with Gold 200's print grain index or with a display-pixel variance.

**Implementation consequence.** Start with **one named process condition** (e.g. 400TX, 35 mm, D-76 large tank, 20°C, 8-minute plotted curve), then digitize additional plotted development-time curves before offering a process/development control. Model a single panchromatic layer exposure, not three independent colored negative layers. Convert camera RGB to film exposure with a stated assumed luminance/spectral weighting; camera RGB cannot reconstruct scene spectra, so colored subjects remain approximate. Evaluate the measured negative-density curve per pixel, add correlated grain in negative-density space, then invert/render through a separate virtual black-and-white paper or scan curve. Do not simulate push processing by merely shifting the final output black point or contrast.

**Initial graph readings for 400TX, 35 mm, D-76 large tank, 8 minutes.** PDF page 8 was rendered at 300 dpi (2550 × 3300 pixels). In the upper-left chart, x≈339 maps to log H −4, x≈954 to 0, y≈1033 to diffuse visual density 0, and y≈264 to density 4. The *8-minute* line is the third from the top after the curves separate (short dashes in the legend). The toe lines converge and the printed dashes interrupt the stroke, so allow at least ±0.05 density and ±0.04 log-H; the last point is near the chart's drawn curve end. These readings are especially provisional and should be independently checked before numerical accuracy claims.

| log H | Diffuse visual negative density |
| ---: | ---: |
| −3.4 | 0.29 |
| −3.0 | 0.29 |
| −2.5 | 0.45 |
| −2.0 | 0.72 |
| −1.5 | 1.03 |
| −1.0 | 1.33 |
| −0.5 | 1.65 |
| 0.0 | 1.93 |
| +0.3 | 2.09 |

## Kodak Professional T-Max 100 / 100TMX: black-and-white negative

Source: Kodak Alaris, [*KODAK PROFESSIONAL T-MAX 100 Film*, F-4016, June 2018](https://www.kodakprofessional.com/sites/default/files/wysiwyg/pro/resources/f4016_TMax_100.pdf). See PDF pages 1, 2–3, 7, 8, and 9 (one-based).

**Published observations.** Kodak gives nominal EI 100 and describes T-Grain emulsion, very fine grain, high sharpness, and broad latitude (page 1). The same publication says exposure and development should be tested together, and that altering development time changes negative contrast (pages 1 and 7). Page 8 plots the spectral response and **diffuse visual negative-density versus log exposure** under daylight exposure for multiple D-76 small-tank times at 20°C: **6, 7.5, and 10 minutes**. Additional page-8 curves use T-MAX RS or T-MAX developer and must not be mixed into a D-76 profile. Page 9 plots contrast index against development time. Page 8 reports **diffuse RMS granularity 8**, read at net diffuse density 1.00 using a 48 µm aperture and 12× magnification after D-76 at 20°C; it also reports resolving power of 63 lines/mm at test-object contrast 1.6:1 and 200 lines/mm at 1000:1. These controlled conditions matter. Page 2 gives reciprocity corrections, including +1/3 stop at 1 second, +1/2 at 10 seconds, and +1 at 100 seconds. A normal digital photo edit has no equivalent exposure duration unless shutter metadata are used deliberately.

**Implementation consequence.** Use its own digitized 100TMX density curve and process condition. A T-Max 100 mode should differ from Tri-X in its actual curve and texture scale, not only in final contrast and grain amount. The RMS values 8 and 17 justify an ordering under their respective Kodak measurement methods, but the sheets use different developers; they do **not** yield a defensible 8:17 pixel-amplitude ratio. If offering reciprocity, require known shutter duration and make it an opt-in physical-film study rather than silently inferring it from RAW exposure compensation.

## Model and verification boundaries

1. **Negative response:** for each color-sensitive layer or panchromatic B&W layer, map scene-linear exposure to `log10(H)`, then through a monotone digitization of the relevant manufacturer's characteristic curve. Preserve the recorded chart reference and process condition. Each exposure stop shifts log H by `log10(2) ≈ 0.301`, so a −2/0/+2 EV study must traverse different parts of the toe and straight section, rather than reuse one rendered look.
2. **Spatial texture:** synthesize stable, spatially correlated density perturbations at a declared physical/digital scale, then carry them through the negative-to-positive stage. Expect visibility and color/tonal response to vary with the local curve slope and output stage. Manufacturer grain metrics alone do not specify the required correlation spectrum, layer covariance, or noise amplitude. Native-scale scans and a defined scanner MTF are required to tune these.
3. **Positive output:** identify print paper, scanner, or virtual grading response separately. The negative datasheets do not define FilmLab's final display RGB. A monochrome virtual paper response can be a useful provisional first implementation for Tri-X and T-Max. Color negative dye spectra and paper response need more than three density curves for a full spectral print model.
4. **Verification:** keep numeric graph readings, digitization method, chart pixels/axes, and uncertainty in versioned `Research/` data. Check knot values, monotonicity, process-condition provenance, and −2/0/+2 EV behavior in automated rendering probes. Compare native-resolution grain and positive color against licensed, matched film scans before claiming any stock match. A pleasing image and a passing shader test do not prove stock accuracy.

**Recommended order:** Gold 200 first, because FilmLab already has a three-layer color-negative density pipeline and an optional Endura Premier paper study; then Tri-X 400 and T-Max 100 through a distinct one-layer B&W negative path with explicit virtual print/scan output. All three should initially be labeled **density studies**.

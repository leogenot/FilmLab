# Public flat-field grain references

These CC0 scans provide **scanner-convolved spatial texture** from real negatives. They are useful for checking whether FilmLab's virtual grain is plausibly fine or coarse at a similar pixel pitch. They cannot determine a unique stock grain amplitude, scene-dependent grain, dye-layer covariance, or the appearance of a positive print. The source scans remain outside the repository; the JSON measurements are small derived data.

| Stock and source | Source SHA-256 | Local measurement |
| --- | --- | --- |
| [Kodak Ektar 100 uniform 35 mm negative, scan 04](https://commons.wikimedia.org/wiki/File:KodakEktar100GrainScan04.tif) | `4f6e403f55b5fd43af84a009fd78b1e5661c8f550f0a1c5b9b2f8ffaa6f88bd3` | `ektar100-flatfield-metrics.json` |
| [Kodak Tri-X 400, scan 1](https://commons.wikimedia.org/wiki/File:Tri-x_400_grain1.png) | `b5da2224aa3b978362f33ecb5f3b971893cd948c3ab7f8c0ccc81b75beff76f0` | `trix400-flatfield-metrics.json` |
| [Kodak Tri-X 400, scan 2](https://commons.wikimedia.org/wiki/File:Tri-x_400_grain2.png) | `111f4bf0feb3abc21d5e539872cc9bf85fa69411f58cdbf45a5df58203b9e21c` | `trix400-flatfield-2-metrics.json` |
| [Kodak T-Max 100 uniform negative](https://commons.wikimedia.org/wiki/File:Tmax100_Grain.png) | `4a65c1192cf4f970ebedee0be88cdbea7a0b6ea6166f89e14980798314960206` | `tmax100-flatfield-metrics.json` |

The source descriptions identify a Nikon Coolscan V ED at 4000 dpi. The Ektar source is a 16-bit RGB TIFF with an infrared alpha channel; the monochrome scans are 16-bit grayscale PNGs. The photographer normalized the monochrome scans toward CIELAB middle gray, so even their relative variance does not compare physical density noise across stocks. All files include film, development, scanner optics, sensor noise, and processing. Strong horizontal/vertical correlation differences suggest a substantial scanner contribution. The apparent source pitch is about 6.35 µm per pixel; FilmLab's 7008-pixel virtual 35 mm frame is about 5.14 µm per pixel, so comparisons require spatial resampling or a fixed physical-frequency axis.

`measure-flatfield-grain.py` samples nine interior 512-pixel tiles per channel. It computes negative log of normalized scanner signal, removes low-frequency variation with a 16-pixel Gaussian low pass, clips residuals to five median absolute deviations to limit dust and scratches, and records residual variance and horizontal/vertical autocorrelation through eight pixels. The JSON retains each tile and median summaries. It makes no scanner-linearity claim.

The two Tri-X scans give horizontal one-pixel correlations of 0.423 and 0.455; T-Max gives 0.287. Vertical one-pixel correlations are 0.662, 0.682, and 0.584, respectively. This supports a **qualitative** finer T-Max texture under this scanning workflow, consistent with FilmLab's existing finer T-Max procedural field. The anisotropy and single T-Max sample do not justify fitting a stock-specific kernel from those numbers. Ektar's channel measurements likewise cannot determine the covariance of its three dye-cloud layers after scanner color processing.

To reproduce, download each original file from its Commons page, verify its SHA-256, then run `python Research/measure-flatfield-grain.py SCAN --kind ektar` for Ektar or `--kind bw` for the monochrome scans. The script needs NumPy and Pillow; TIFF additionally needs tifffile. Python package versions and scanner output may affect the last decimal place. Do not commit the source images.

## What would close the remaining gap

For an accuracy claim, obtain a controlled set of matched digital RAW and film captures at several exposure stops, including a neutral and color target. Keep development and scanning fixed, retain linear high-bit scans and scanner characterization, then reserve entire scenes for validation. Flat fields at several film densities and repeated blank scans would allow film texture to be separated from scanner noise. Published stock curves can constrain the fit, but cannot substitute for these measurements.

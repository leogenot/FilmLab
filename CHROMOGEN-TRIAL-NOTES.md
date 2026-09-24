# Chromogen trial observations for FilmLab

Observed in the installed macOS trial on 24 September 2026 using disposable copies of `LEO00403.ARW` and a JPEG export of the same scene. The user's original file and any pre-existing edits were not changed. Chromogen wrote edit sidecars beside the disposable copies in `/private/tmp`.

## Confirmed from the running app

- The Sony RAW opens as a 16-bit, 32.7 MP image. The same scene opened as a JPEG is marked 8-bit. The editor shows clipping percentages, a histogram, a GPU preview status, and source metadata.
- The first workspace is **Film Stock**, explicitly described as “Choose the stock before correction.” Applying included Aureon 100 creates a stock card with alternate looks and controls for Stock Amount, Film Grain, Film Halation, Shot Exposure, Development, Anchor black point, and Film scan edge. RAW starts at 100% Stock Amount; JPEG starts at 70%.
- Dragging Shot Exposure from As metered to Under 2 changed the rendered image to flatter, thinner shadows; Over +2 was brighter/softer. This is a separate control from ordinary exposure. The Development control is also distinct, though I did not successfully change its value through UI automation in this pass.
- **Develop** shows White Balance, RAW Develop, Curves and Geometry for RAW. RAW Develop includes Exposure, Contrast, Highlights, Shadows, Whites, Blacks and Highlight Recovery. The JPEG path instead labels the card Basic Adjustments and omits Highlight Recovery. RAW showed an as-shot 5450 K / tint -31 on this file; the JPEG showed 5000 K / tint 0.
- **Color** contains separate Master, Shadows, Midtones and Highlights grading wheels, plus master saturation, vibrance, a color mixer, hue curves, Color Unify and a skin-evening control. Its description is “Color timing, then selected colour edits.”
- **Effects** is described as “Physical film and scan behavior.” It groups Detail and Acutance; Grain; Halation, Bloom, Light Leak, Pre-Exposed, Dehaze and Scan; Lens and Vignetting; then presentation effects. With Aureon 100 selected on JPEG, Grain and Halation both show On at 100% and Grain Type reads “Aureon 100 (auto)”. Grain offers Amount, Type, Size, Crispness, Colour and Shadow grain. Halation offers Amount, Threshold, Source Size, Radius, Tint and Glow. Detail offers Sharpening, Sharpen Radius, Noise Reduction and Color Noise; Acutance offers Softness and Edge. Scan has Tone, Night, Glow, Balance, Warmth and Glow warmth.
- Moving the Master grading wheel tinted the whole JPEG magenta and changed its histogram; moving the Shadows wheel tinted mainly dark regions teal/green. Both were reset afterward. This verifies region-aware grading at the visible UI level.
- The UI keeps the image dominant on a near-black canvas with a quiet left navigation rail and a right inspector. Within the inspector, one or two cards are expanded at once; the rest are narrow rows. A section can be hidden or reset without leaving the workspace. Controls show their current numeric value on the same line as the name.

## Edit-state evidence

The generated `.chromogen.json` sidecars are non-destructive edit state, not the rendering implementation. The files carry separate fields for `stockProfile`, `stockAmount`, `stockGrainPct`, `stockHalationPct`, `shotExposure`, `pushPull`, `grain` and `halation` effect parameters, `scan*` controls, grading wheel values, and RAW-only `rawExp`, `rawHi`, `rawSh`, `rawHiRec`, sharpening and noise-reduction values. On the disposable copies, the saved stock amount was 100 for RAW and 70 for JPEG. The UI also shows stock-driven Grain and Halation as active in Effects. These observations support separate editable controls in FilmLab, but do not establish whether Chromogen renders them as separate passes or combines the values inside one stock transform.

The sidecar does **not** disclose Chromogen's film measurements, transform equations, processing order, or GPU shaders. Workspace ordering and field names are useful design evidence, but cannot establish exact internal compositing order.

## Revised FilmLab target

Use distinct input pipelines that converge on a high-precision working image:

```
RAW → demosaic / lens / as-shot WB / highlight recovery ┐
                                                      ├→ scene normalization → film stock response
JPEG → profile decode / baked-tone normalization ─────┘                         │
                                            Shot Exposure and Development ────────┘
                    → tone and color grading → grain / halation / acutance / scan effects
                    → output color space / export
```

The ordering of Shot Exposure, Development, stock response and texture must be determined by our own visual and numeric experiments; the diagram captures conceptual dependencies, not Chromogen's code. For the next implementation phase, prioritize a correct 16-bit/float RAW path, consistent JPEG normalization, non-destructive edit state, preview/export parity, and one stock with exposure-dependent tone and color. UI work can follow the same restrained three-zone pattern without copying their branding.

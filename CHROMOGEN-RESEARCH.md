# Chromogen research for FilmLab

Reviewed 24 September 2026: public homepage, film-accuracy exhibit, release notes, privacy and terms pages. Also operated the live stock selector, alternate sample scene, halation and exposure demos, and the accuracy exhibit in the Codex in-app browser. Chrome control was unavailable in this session. This is an analysis of public material, not access to Chromogen's application or private calibration data.

## What the public evidence supports

- Chromogen says it photographs a 140-patch reference target on each film stock, scans the result, derives a density-versus-log-exposure characteristic curve, and models cyan, magenta and yellow dye-layer behavior separately. The accuracy page lets visitors toggle the patch target, probe the curve, and pull apart an illustrated dye stack. Source: https://chromogen.app/accuracy
- The homepage shows stock-specific appearance under changed exposure, including underexposure becoming thin, flatter and less saturated, and overexposure becoming softer and pastel. It separates Shot Exposure from Push/Pull Development. Source: https://chromogen.app/#workspace and https://chromogen.app/#exposure
- Release notes say the film response affects tonal roll-off, grain by stock and tonal region, halation by light-source size and stock, and acutance/adjacency edges. They also document RAW highlight recovery, Kelvin white balance, lens correction before the film look, and separate default stock strengths for RAW (100%) and JPEG (70%). Source: https://chromogen.app/changelog
- Film editing controls include stock amount, Shot Exposure, Push/Pull, grain, halation, white balance, exposure, contrast, highlights, shadows, whites, blacks, color grading wheels, color mixer, curves, local masks, and export color spaces. Source: https://chromogen.app/ and https://chromogen.app/changelog
- The public exposure comparison references fixed JPG assets (`film-look-minus-2-stops.jpg`, `film-look-plus-2-stops.jpg`, and preset equivalents). The website does not prove that its interactive display runs the desktop rendering engine. The accuracy exhibit is canvas-based and presents the measurement concept; it does not publish numeric stock profiles or the exact algorithm.

## Implications for FilmLab's image pipeline

1. Normalize RAW/JPEG inputs into a color-managed, high-precision working representation. Preserve RAW latitude and avoid treating camera-rendered JPEG as a flat RAW equivalent.
2. Apply technical white balance, exposure, highlight recovery and lens correction before a film stock model.
3. Give each stock an exposure-dependent tone response and a color transform that varies with tone/exposure. Avoid relying on a single fixed LUT as the complete stock.
4. Treat Shot Exposure and Push/Pull as distinct operations. The former changes the simulated negative's exposure and scan balance; the latter changes development behavior, including contrast, grain and edge response.
5. Add stock-specific grain, halation and acutance after the main tone/color response, with previews at fit and 100% zoom.
6. Grade with curves, tonal color wheels and local adjustments; export through an explicit output color space with preview/export parity.

These are a proposed architecture inferred from public descriptions, not a reproduction of Chromogen's proprietary pipeline. The decisive research task is controlled reference capture and scan comparison for one stock across multiple exposures, illuminants and scenes.

## Focused feature inventory

**Core first:** RAW/JPEG open, non-destructive edit state, preview/export parity, technical white balance and exposure, one measured stock, stock amount, tone/color controls, full-resolution JPEG/TIFF export.

**Next:** Shot Exposure, Push/Pull, grain, halation, curves, grading wheels, before/after compare, 100% zoom and clipping warnings.

**Later if useful:** masks and dodge/burn, lens profiles, preset import, batch synchronization, print soft proofing.

**Outside FilmLab's current scope:** culling/library management, text/layout, social exports, mockups, retouching and instant-print frames.

## Visual and interaction notes

The site uses a near-black background (computed homepage body `rgb(8, 8, 10)`), soft off-white text, fine gray rules, small spaced uppercase labels, one restrained warm amber accent, and generous empty space. Its stock browser gives the photograph most of the area and puts concise metadata directly over it. The darkroom demos show one effect per card and keep the control next to the relevant image. The accuracy page uses disclosure-like numbered stages to reveal detail progressively.

The published desktop screenshot uses three zones: a narrow navigation rail, a large uninterrupted photograph on a charcoal canvas, and a right-hand inspector of stacked dark cards. The top bar has a few high-value actions; a slim tool rail sits beside the image. Sliders show numeric values at the edge, with muted tracks and minimal accent color. The histogram is compact above the adjustment cards. The image remains the visual priority. Source screenshot: https://chromogen.app/assets/chromogen-develop-workspace.jpg?v=3

For FilmLab, keep the calm composition but simplify it: one image canvas, a compact right inspector grouped into Develop / Film / Grade, a quiet top bar for Open, Compare and Export, and optional collapse of the controls. Use dense controls only when a group is opened. Avoid imitating Chromogen's branding, stock names or artwork. The current FilmLab prototype is much brighter and more basic than this direction.

## Site coverage and limits

The homepage links to four standalone first-party pages: `/accuracy`, `/changelog`, `/privacy`, and `/terms`. The latter two concern data handling and licensing rather than image processing. Homepage sections are anchor targets, not separate pages. I inspected the linked public pages and the image-processing demos; I did not install or run Chromogen's desktop app. Chrome automation was unavailable, so the live visual inspection used the in-app browser. The public site does not provide the reference scans, measured patch values as a dataset, stock curve tables, or source code needed to reproduce its rendering exactly.

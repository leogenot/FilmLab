import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

@main
struct RenderingProbe {
  static func main() {
    let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
    let context = CIContext(options: [
      .workingColorSpace: space,
      .workingFormat: CIFormat.RGBAf,
    ])
    let previewContext = CIContext(options: [
      .workingColorSpace: space,
      .workingFormat: CIFormat.RGBAh,
    ])
    let densityContext = CIContext(options: [
      .workingColorSpace: NSNull(),
      .workingFormat: CIFormat.RGBAf,
    ])
    let negative = FilmKernels.kernel("measuredNegative")!
    let positive = FilmKernels.kernel("portraPositive")!
    let opticalPrint = FilmKernels.kernel("opticalPremierPositive")!
    let multigradePrint = FilmKernels.kernel("multigradePositive")!
    let sceneLight = FilmKernels.kernel("shapeSceneLight")!
    let renderedInputTone = FilmKernels.kernel("renderedInputTone")!
    let outputShoulder = FilmKernels.kernel("outputShoulder")!
    let outputToneCurve = FilmKernels.kernel("outputToneCurve")!
    let vibrance = FilmKernels.kernel("vibrance")!
    let gamutWarning = FilmKernels.kernel("outputGamutWarning")!

    func patch(_ value: Double) -> CIImage {
      CIImage(color: CIColor(red: value, green: value, blue: value, colorSpace: space)!)
        .cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    func channels(_ image: CIImage) -> [Float] {
      var rgba = [Float](repeating: 0, count: 4)
      rgba.withUnsafeMutableBytes { bytes in
        context.render(
          image, toBitmap: bytes.baseAddress!, rowBytes: 16,
          bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
          format: .RGBAf, colorSpace: space)
      }
      return Array(rgba.prefix(3))
    }

    func warned(_ red: Double, _ green: Double, _ blue: Double) -> [Float] {
      let input = CIImage(
        color: CIColor(red: red, green: green, blue: blue, colorSpace: space)!
      ).cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
      return channels(gamutWarning.apply(extent: input.extent, arguments: [input])!)
    }
    let withinGamut = warned(0.2, 0.3, 0.4)
    precondition(abs(withinGamut[0] - 0.2) < 0.001)
    precondition(abs(withinGamut[1] - 0.3) < 0.001)
    let aboveGamut = warned(1.25, 0.3, 0.4)
    precondition(aboveGamut[0] > 0.9 && aboveGamut[1] < 0.3)
    let belowGamut = warned(-0.1, 0.3, 0.4)
    precondition(belowGamut[2] > 0.8 && belowGamut[0] < 0.1)

    func rendered(_ stock: Double, _ exposure: Double) -> [Float] {
      let source = patch(0.18)
      let density = negative.apply(
        extent: source.extent, arguments: [source, exposure, 0.0, stock])!
      let output = positive.apply(
        extent: source.extent,
        arguments: [density, source, exposure, 1.0, 0.0, 0.0, stock])!
      return channels(output)
    }

    func optical(
      _ stock: Double, _ shotEV: Double, _ paperEV: Double,
      _ light: Double = 0.18, magenta: Double = 0, yellow: Double = 0
    ) -> [Float] {
      let source = patch(light)
      let density = negative.apply(
        extent: source.extent, arguments: [source, shotEV, 0.0, stock])!
      let printImage = opticalPrint.apply(
        extent: source.extent,
        arguments: [density, source, shotEV, 1.0, paperEV, magenta, yellow, stock])!
      return channels(printImage)
    }
    for stock in [1.0, 2.0, 3.0] {
      let neutral = optical(stock, 0, 0)
      precondition(
        neutral.allSatisfy { $0.isFinite && abs($0 - 0.18) < 0.002 },
        "Optical print reference was not neutral for stock \(stock)")
      let lighter = optical(stock, 0, -1)
      let darker = optical(stock, 0, 1)
      precondition(
        zip(lighter, darker).allSatisfy { $0 > $1 },
        "Paper exposure did not darken print for stock \(stock)")
      let shadow = optical(stock, -2, 0)
      let highlight = optical(stock, 2, 0)
      precondition(
        zip(shadow, highlight).allSatisfy { $0 < $1 },
        "Shot exposure did not lighten print for stock \(stock)")
      let moreMagenta = optical(stock, 0, 0, magenta: 1)
      let moreYellow = optical(stock, 0, 0, yellow: 1)
      precondition(moreMagenta.allSatisfy(\.isFinite) && moreYellow.allSatisfy(\.isFinite))
      precondition(moreMagenta[1] > neutral[1], "Magenta filtration did not reduce green exposure")
      precondition(moreYellow[2] > neutral[2], "Yellow filtration did not reduce blue exposure")
    }

    func monochrome(_ stock: Double, _ light: Double, _ grade: Double, _ paperEV: Double = 0)
      -> [Float]
    {
      let source = patch(light)
      let density = negative.apply(
        extent: source.extent, arguments: [source, 0.0, 0.0, stock])!
      let printImage = multigradePrint.apply(
        extent: source.extent,
        arguments: [density, source, 0.0, 1.0, paperEV, grade, stock])!
      return channels(printImage)
    }
    for stock in [4.0, 5.0] {
      let neutral = monochrome(stock, 0.18, 3)
      precondition(neutral.allSatisfy { $0.isFinite && abs($0 - 0.18) < 0.002 })
      let softShadow = monochrome(stock, 0.08, 0)[0]
      let softHighlight = monochrome(stock, 0.35, 0)[0]
      let hardShadow = monochrome(stock, 0.08, 6)[0]
      let hardHighlight = monochrome(stock, 0.35, 6)[0]
      precondition(softShadow < softHighlight && hardShadow < hardHighlight)
      precondition(hardHighlight - hardShadow > softHighlight - softShadow)
      precondition(monochrome(stock, 0.18, 3, 1)[0] < neutral[0])
    }

    func opticalColor(_ stock: Double, red: Double, green: Double, blue: Double) -> [Float] {
      let source = CIImage(
        color: CIColor(red: red, green: green, blue: blue, colorSpace: space)!
      ).cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
      let density = negative.apply(
        extent: source.extent, arguments: [source, 0.0, 0.0, stock])!
      let printImage = opticalPrint.apply(
        extent: source.extent,
        arguments: [density, source, 0.0, 1.0, 0.0, 0.0, 0.0, stock])!
      return channels(printImage)
    }
    let samplePrints = [1.0, 2.0, 3.0].map {
      opticalColor($0, red: 0.34, green: 0.12, blue: 0.07)
    }
    precondition(
      samplePrints.allSatisfy { channels in
        channels.allSatisfy { $0.isFinite && $0 >= 0 }
      }, "Spectral print generated an invalid color")
    precondition(
      zip(samplePrints[0], samplePrints[1]).contains { abs($0 - $1) > 0.001 },
      "Portra and Ektar used an indistinguishable print response")
    precondition(
      zip(samplePrints[1], samplePrints[2]).contains { abs($0 - $1) > 0.001 },
      "Ektar and Gold used an indistinguishable print response")

    let coloredLight = CIImage(
      color: CIColor(red: 0.22, green: 0.18, blue: 0.13, colorSpace: space)!
    ).cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
    func balanced(_ image: CIImage) -> CIImage {
      let balance = CIFilter.temperatureAndTint()
      balance.inputImage = image
      balance.neutral = CIVector(x: 6500, y: 0)
      balance.targetNeutral = CIVector(x: 6100, y: -35)
      return balance.outputImage!
    }
    func film(_ input: CIImage, exposure: Double) -> CIImage {
      let density = negative.apply(
        extent: input.extent, arguments: [input, exposure, 0.0, 1.0])!
      return positive.apply(
        extent: input.extent,
        arguments: [density, input, exposure, 1.0, 0.0, 0.0, 1.0])!
    }
    for exposure in [-2.0, 2.0] {
      let beforeFilm = channels(film(balanced(coloredLight), exposure: exposure))
      let afterFilm = channels(balanced(film(coloredLight, exposure: exposure)))
      let difference = zip(beforeFilm, afterFilm).map { abs($0 - $1) }.max() ?? 0
      precondition(difference > 0.001, "Film-light balance acted like output balance")
    }

    func inputTone(_ light: Double, _ slope: Double) -> Float {
      let source = patch(light)
      return channels(
        renderedInputTone.apply(extent: source.extent, arguments: [source, slope])!
      )[0]
    }
    precondition(abs(inputTone(0.18, 0.5) - 0.18) < 0.001, "Input tone shifted gray")
    precondition(inputTone(0.01, 0.5) > 0.01, "Input tone did not lift dark values")
    precondition(inputTone(1, 0.5) < 1, "Input tone did not compress bright values")
    precondition(inputTone(0.01, 1.5) < 0.01, "Expanded input tone did not lower shadows")
    precondition(inputTone(1, 1.5) > 1, "Expanded input tone did not raise highlights")
    for slope in [0.5, 1.5] {
      let below = inputTone(0.000001 * 0.999, slope)
      let above = inputTone(0.000001 * 1.001, slope)
      precondition(
        abs(below - above) < 0.000002,
        "Rendered-input tone has a dark-boundary jump at slope \(slope)")
      precondition(inputTone(0, slope) == 0, "Rendered-input tone changed black")
    }
    precondition(inputTone(0.0000001, 0.5) > 0.0000001)
    precondition(inputTone(0.0000001, 1.5) < 0.0000001)
    let coloredInput = CIImage(
      color: CIColor(red: 0.4, green: 0.2, blue: 0.1, colorSpace: space)!
    ).cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
    let tonedColor = channels(
      renderedInputTone.apply(extent: coloredInput.extent, arguments: [coloredInput, 0.5])!)
    precondition(abs(tonedColor[0] / tonedColor[1] - 2) < 0.002, "Input tone shifted hue")
    precondition(abs(tonedColor[1] / tonedColor[2] - 2) < 0.002, "Input tone shifted hue")

    func shoulder(_ red: Double, _ green: Double, _ blue: Double, _ amount: Double) -> [Float] {
      let source = CIImage(
        color: CIColor(red: red, green: green, blue: blue, colorSpace: space)!
      ).cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
      return channels(outputShoulder.apply(extent: source.extent, arguments: [source, amount])!)
    }
    precondition(abs(shoulder(0.5, 0.4, 0.3, 1)[0] - 0.5) < 0.001)
    precondition(abs(shoulder(2, 1, 0.5, 0)[0] - 2) < 0.001)
    let rolledColor = shoulder(2, 1, 0.5, 1)
    precondition(rolledColor[0] < 1 && rolledColor[0] > 0.95)
    precondition(abs(rolledColor[0] / rolledColor[1] - 2) < 0.002)
    precondition(abs(rolledColor[1] / rolledColor[2] - 2) < 0.002)
    precondition(shoulder(1, 0.5, 0.25, 1)[0] < rolledColor[0])
    let shoulderSource = CIImage(
      color: CIColor(red: 2, green: 1, blue: 0.5, colorSpace: space)!
    ).cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
    let shoulderImage = outputShoulder.apply(
      extent: shoulderSource.extent, arguments: [shoulderSource, 1.0])!
    var previewRGBA = [Float](repeating: 0, count: 4)
    previewRGBA.withUnsafeMutableBytes { bytes in
      previewContext.render(
        shoulderImage, toBitmap: bytes.baseAddress!, rowBytes: 16,
        bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
        format: .RGBAf, colorSpace: space)
    }
    precondition(zip(previewRGBA.prefix(3), rolledColor).allSatisfy { abs($0 - $1) < 0.002 })

    func curved(_ light: Double, _ shadow: Double, _ midtone: Double, _ highlight: Double)
      -> Float
    {
      let source = patch(light)
      return channels(
        outputToneCurve.apply(
          extent: source.extent, arguments: [source, shadow, midtone, highlight])!)[0]
    }
    for shadow in [-0.14, 0.14] {
      let below = curved(0.000001 * 0.999, shadow, 0, 0)
      let above = curved(0.000001 * 1.001, shadow, 0, 0)
      precondition(
        abs(below - above) < 0.00000001,
        "Output tone curve has a near-black jump at shadow \(shadow)")
      precondition(curved(0, shadow, 0, 0) == 0)
    }
    precondition(abs(curved(0.18, 0, 0, 0) - 0.18) < 0.001)
    precondition(abs(curved(0.2, 0.1, 0, 0) - 0.3) < 0.001)
    precondition(abs(curved(0.5, 0, -0.1, 0) - 0.4) < 0.001)
    precondition(abs(curved(0.8, 0, 0, 0.1) - 0.9) < 0.001)
    for settings in [(0.14, -0.14, 0.14), (-0.14, 0.14, -0.14)] {
      var previous: Float = -1
      for step in 0...24 {
        let value = curved(Double(step) * 0.05, settings.0, settings.1, settings.2)
        precondition(value >= previous, "Output tone curve reversed brightness")
        previous = value
      }
    }
    let colorCurveSource = CIImage(
      color: CIColor(red: 0.6, green: 0.3, blue: 0.15, colorSpace: space)!
    ).cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
    let curvedColor = channels(
      outputToneCurve.apply(
        extent: colorCurveSource.extent,
        arguments: [colorCurveSource, 0.1, -0.05, 0.1])!)
    precondition(abs(curvedColor[0] / curvedColor[1] - 2) < 0.002)
    precondition(abs(curvedColor[1] / curvedColor[2] - 2) < 0.002)

    func vibrant(_ red: Double, _ green: Double, _ blue: Double, _ amount: Double) -> [Float] {
      let source = CIImage(
        color: CIColor(red: red, green: green, blue: blue, colorSpace: space)!
      ).cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
      return channels(vibrance.apply(extent: source.extent, arguments: [source, amount])!)
    }
    func luminance(_ color: [Float]) -> Float {
      color[0] * 0.2126 + color[1] * 0.7152 + color[2] * 0.0722
    }
    func chroma(_ color: [Float]) -> Float {
      color.max()! - color.min()!
    }
    let muted = vibrant(0.45, 0.35, 0.30, 0)
    let strong = vibrant(0.65, 0.20, 0.08, 0)
    let mutedRaised = vibrant(0.45, 0.35, 0.30, 1)
    let strongRaised = vibrant(0.65, 0.20, 0.08, 1)
    let mutedLowered = vibrant(0.45, 0.35, 0.30, -1)
    precondition(abs(vibrant(0.18, 0.18, 0.18, 1)[0] - 0.18) < 0.001)
    precondition(abs(luminance(mutedRaised) - luminance(muted)) < 0.001)
    precondition(abs(luminance(mutedLowered) - luminance(muted)) < 0.001)
    precondition(chroma(mutedRaised) > chroma(muted))
    precondition(chroma(mutedLowered) < chroma(muted))
    precondition(
      chroma(mutedRaised) / chroma(muted) > chroma(strongRaised) / chroma(strong) + 0.1,
      "Vibrance did not favor muted color")
    precondition(mutedRaised.min()! >= 0)
    let extendedColor = vibrant(1.4, 0.2, -0.1, 1)
    precondition(abs(extendedColor[0] - 1.4) < 0.001)
    precondition(abs(extendedColor[2] + 0.1) < 0.001)

    for stock in [1.0, 2.0, 3.0, 4.0, 5.0] {
      let under = rendered(stock, -2)
      let normal = rendered(stock, 0)
      let over = rendered(stock, 2)
      for channel in 0..<3 {
        precondition(
          under[channel] < normal[channel] && normal[channel] < over[channel],
          "Stock \(stock) has a reversed exposure response")
        precondition(
          abs(normal[channel] - 0.18) < 0.003,
          "Stock \(stock) lost neutral gray calibration")
      }
    }
    precondition(
      abs(rendered(1, 2)[0] - rendered(2, 2)[0]) > 0.01,
      "Portra and Ektar have indistinguishable bright response")

    func premierPaper(_ stock: Double, _ paperExposure: Double) -> [Float] {
      let source = patch(0.18)
      let density = negative.apply(
        extent: source.extent, arguments: [source, 0.0, 0.0, stock])!
      return channels(
        positive.apply(
          extent: source.extent,
          arguments: [density, source, 0.0, 1.0, 1.0, paperExposure, stock])!)
    }
    for stock in [2.0, 3.0] {
      let paperUnder = premierPaper(stock, -2)
      let paperNormal = premierPaper(stock, 0)
      let paperOver = premierPaper(stock, 2)
      for channel in 0..<3 {
        precondition(
          paperUnder[channel] > paperNormal[channel]
            && paperNormal[channel] > paperOver[channel],
          "Stock \(stock) Endura Premier paper exposure response is reversed")
        precondition(
          abs(paperNormal[channel] - 0.18) < 0.004,
          "Stock \(stock) Endura Premier reference gray is not neutral")
      }
    }

    func shaped(_ light: Double, _ shadowEV: Double, _ highlightEV: Double) -> Float {
      let source = patch(light)
      return channels(
        sceneLight.apply(
          extent: source.extent, arguments: [source, shadowEV, highlightEV])!)[0]
    }
    precondition(
      shaped(0.018, 1, 0) > shaped(0.018, 0, 0) * 1.5,
      "Shadow light does not affect dark pixels")
    precondition(
      abs(shaped(0.18, 1, 0) - 0.18) < 0.001,
      "Shadow light shifted reference gray")
    precondition(
      shaped(1.8, 0, -1) < shaped(1.8, 0, 0) * 0.7,
      "Highlight light does not affect bright pixels")
    precondition(
      abs(shaped(0.18, 0, -1) - 0.18) < 0.001,
      "Highlight light shifted reference gray")
    var bands = Array(repeating: ColorMix(), count: 8)
    bands[0].saturation = -0.5
    func colorPatch(_ red: Double, _ green: Double, _ blue: Double) -> CIImage {
      CIImage(color: CIColor(red: red, green: green, blue: blue, colorSpace: space)!)
        .cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
    }
    let redPatch = colorPatch(0.8, 0.1, 0.08)
    let bluePatch = colorPatch(0.08, 0.2, 0.8)
    let grayPatch = patch(0.18)
    let redMixed = channels(ColorMixer.apply(to: redPatch, adjustments: bands))
    let legacyRedMixed = channels(ColorMixer.apply(to: redPatch, adjustments: bands, version: 1))
    let blueMixed = channels(ColorMixer.apply(to: bluePatch, adjustments: bands))
    let grayMixed = channels(ColorMixer.apply(to: grayPatch, adjustments: bands))
    precondition(
      abs(luminance(redMixed) - luminance([0.8, 0.1, 0.08])) < 0.001,
      "Luminance-preserving mixer changed brightness with only saturation active")
    precondition(
      legacyRedMixed != redMixed,
      "Legacy mixer was not retained as a distinct rendering path")
    precondition(
      redMixed[0] - redMixed[2] < 0.8 - 0.08,
      "Red mixer saturation did not affect red pixels")
    precondition(
      abs(blueMixed[0] - 0.08) < 0.003 && abs(blueMixed[2] - 0.8) < 0.003,
      "Red mixer spilled into blue pixels")
    precondition(
      grayMixed.allSatisfy { abs($0 - 0.18) < 0.001 },
      "Color mixer shifted neutral pixels")
    bands[0] = ColorMix(hue: 0, saturation: 0, luminance: 1)
    let brighterRed = channels(ColorMixer.apply(to: redPatch, adjustments: bands))
    let unchangedBlue = channels(ColorMixer.apply(to: bluePatch, adjustments: bands))
    precondition(
      brighterRed[0] > redMixed[0] + 0.2,
      "Red mixer luminance did not raise the selected color")
    precondition(
      abs(unchangedBlue[2] - 0.8) < 0.003,
      "Red mixer luminance spilled into blue pixels")
    bands[0] = ColorMix()
    bands[5].hue = 30
    let shiftedBlue = channels(ColorMixer.apply(to: bluePatch, adjustments: bands))
    precondition(
      abs(luminance(shiftedBlue) - luminance([0.08, 0.2, 0.8])) < 0.001,
      "Luminance-preserving mixer changed brightness with only hue active")
    precondition(
      abs(shiftedBlue[0] - 0.08) > 0.01 || abs(shiftedBlue[1] - 0.2) > 0.01,
      "Blue mixer hue did not affect blue pixels")
    var channelCurves = Array(repeating: ChannelCurve(), count: 3)
    let neutralCurve = channels(
      ChannelCurves.apply(to: colorPatch(0.5, 0.5, 0.5), curves: channelCurves)!)
    precondition(
      neutralCurve.allSatisfy { abs($0 - 0.5) < 0.001 },
      "Neutral channel curves changed a pixel")
    channelCurves[0].midtone = 0.1
    let redCurve = channels(
      ChannelCurves.apply(to: colorPatch(0.5, 0.5, 0.5), curves: channelCurves)!)
    precondition(
      abs(redCurve[0] - 0.6) < 0.001 && abs(redCurve[1] - 0.5) < 0.001
        && abs(redCurve[2] - 0.5) < 0.001,
      "Red midtone curve did not isolate the red channel")
    let brightCurve = channels(
      ChannelCurves.apply(to: colorPatch(1.4, 0.5, 0.5), curves: channelCurves)!)
    precondition(
      brightCurve[0] > 1.0 && abs(brightCurve[1] - 0.5) < 0.001,
      "Channel curve lost extended highlight headroom")
    func negativeDensity(_ stock: Double, _ logH: Double) -> [Float] {
      let anchor = stock == 1 ? -1.44 : (stock == 2 ? -0.84 : (stock == 3 ? -1.14 : -1.5))
      let source = patch(0.18)
      let exposure = (logH - anchor) / log10(2)
      let density = negative.apply(
        extent: source.extent, arguments: [source, exposure, 0.0, stock])!
      var rgba = [Float](repeating: 0, count: 4)
      rgba.withUnsafeMutableBytes { bytes in
        densityContext.render(
          density, toBitmap: bytes.baseAddress!, rowBytes: 16,
          bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBAf,
          colorSpace: nil)
      }
      return Array(rgba.prefix(3))
    }
    func chartRows(_ filename: String) -> [(Double, [Float])] {
      let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
      let url = root.appendingPathComponent("Research/\(filename)")
      let rows = try! String(contentsOf: url, encoding: .utf8)
        .split(whereSeparator: \.isNewline).dropFirst()
      return rows.map { row in
        let values = row.split(separator: ",").compactMap { Double($0) }
        precondition(values.count == 4, "Invalid density chart row in \(filename): \(row)")
        return (values[0], [Float(values[3]), Float(values[2]), Float(values[1])])
      }
    }
    for (stock, filename) in [
      (1.0, "portra400-density.csv"), (2.0, "ektar100-density.csv"),
      (3.0, "gold200-density.csv"),
    ] {
      let rows = chartRows(filename)
      precondition(rows.count == 9)
      for (exposure, expected) in rows {
        let actual = negativeDensity(stock, exposure)
        for channel in 0..<3 {
          precondition(
            abs(actual[channel] - expected[channel]) < 0.0003,
            "Stock \(stock) at log H \(exposure) differs from \(filename): \(actual), \(expected)")
        }
      }
      for index in 0..<(rows.count - 1) {
        let midpoint = (rows[index].0 + rows[index + 1].0) / 2
        let actual = negativeDensity(stock, midpoint)
        for channel in 0..<3 {
          precondition(
            actual[channel] >= rows[index].1[channel]
              && actual[channel] <= rows[index + 1].1[channel],
            "Stock \(stock) channel \(channel) reversed between chart samples")
        }
      }
    }
    for (stock, filename, expectedCount) in [
      (4.0, "trix400-density.csv", 9), (5.0, "tmax100-density.csv", 10),
    ] {
      let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Research/\(filename)")
      let rows = try! String(contentsOf: url, encoding: .utf8)
        .split(whereSeparator: \.isNewline).dropFirst().map { row -> (Double, Float) in
          let values = row.split(separator: ",").compactMap { Double($0) }
          precondition(values.count == 2)
          return (values[0], Float(values[1]))
        }
      precondition(rows.count == expectedCount)
      for (logH, expected) in rows {
        let actual = negativeDensity(stock, logH)
        precondition(
          actual.allSatisfy { abs($0 - expected) < 0.0003 },
          "Stock \(stock) density differs from \(filename) at \(logH)")
      }
      for index in 0..<(rows.count - 1) {
        let midpoint = (rows[index].0 + rows[index + 1].0) / 2
        let actual = negativeDensity(stock, midpoint)[0]
        precondition(
          actual >= rows[index].1 && actual <= rows[index + 1].1,
          "Stock \(stock) density reversed between chart samples")
      }
    }
    let trixColor = colorPatch(0.5, 0.2, 0.05)
    let trixNegative = negative.apply(
      extent: trixColor.extent, arguments: [trixColor, 0.0, 0.0, 4.0])!
    let trixPositive = channels(
      positive.apply(
        extent: trixColor.extent,
        arguments: [trixNegative, trixColor, 0.0, 1.0, 0.0, 0.0, 4.0])!)
    precondition(
      trixPositive.max()! - trixPositive.min()! < 0.0001,
      "Tri-X positive is not monochrome")
    let tmaxNegative = negative.apply(
      extent: trixColor.extent, arguments: [trixColor, 0.0, 0.0, 5.0])!
    let tmaxPositive = channels(
      positive.apply(
        extent: trixColor.extent,
        arguments: [tmaxNegative, trixColor, 0.0, 1.0, 0.0, 0.0, 5.0])!)
    precondition(
      tmaxPositive.max()! - tmaxPositive.min()! < 0.0001,
      "T-Max positive is not monochrome")
    precondition(
      abs(rendered(4, 2)[0] - rendered(5, 2)[0]) > 0.01,
      "Tri-X and T-Max bright responses are indistinguishable")
    precondition(
      abs(rendered(4, 2)[0] - rendered(1, 2)[0]) > 0.01,
      "Tri-X is indistinguishable from Portra overexposure")
    for (stock, upperEnd) in [(1.0, 0.5), (2.0, 1.0), (3.0, 0.85), (4.0, 0.3), (5.0, 0.65)] {
      let distance = 0.005
      let before = negativeDensity(stock, upperEnd - distance)
      let atEnd = negativeDensity(stock, upperEnd)
      let after = negativeDensity(stock, upperEnd + distance)
      for channel in 0..<3 {
        let slopeBefore = (atEnd[channel] - before[channel]) / Float(distance)
        let slopeAfter = (after[channel] - atEnd[channel]) / Float(distance)
        precondition(
          abs(slopeAfter / slopeBefore - 1) < 0.04,
          "Stock \(stock) channel \(channel) has a density slope jump: \(before), \(atEnd), \(after); \(slopeBefore), \(slopeAfter)"
        )
      }
    }
    func paperOutput(_ stock: Double, _ paperLogH: Double) -> [Float] {
      let reference = negativeDensity(stock, stock == 1 ? -1.44 : (stock == 2 ? -0.84 : -1.14))
      let shift = stock == 1 ? 0.8 : 0.6
      let density = colorPatch(
        Double(reference[0]) - shift,
        Double(reference[1]) - shift,
        Double(reference[2]) - shift)
      let paperBase = stock == 1 ? -1.625 : -1.4
      let paperEV = (paperLogH - paperBase - shift) / log10(2)
      return channels(
        positive.apply(
          extent: density.extent,
          arguments: [density, patch(0.18), 0.0, 1.0, 1.0, paperEV, stock])!)
    }
    for stock in [1.0, 2.0, 3.0] {
      let endpoint = -0.25
      let distance = 0.01
      let before = paperOutput(stock, endpoint - distance)
      let atEnd = paperOutput(stock, endpoint)
      let after = paperOutput(stock, endpoint + distance)
      for channel in 0..<3 {
        let slopeBefore = (atEnd[channel] - before[channel]) / Float(distance)
        let slopeAfter = (after[channel] - atEnd[channel]) / Float(distance)
        precondition(after[channel] <= atEnd[channel], "Paper shoulder reverses exposure")
        if abs(slopeBefore) > 0.00005 {
          precondition(
            abs(slopeAfter / slopeBefore - 1) < 0.3,
            "Paper stock \(stock) channel \(channel) has a slope jump: \(slopeBefore), \(slopeAfter)"
          )
        } else {
          precondition(
            abs(slopeAfter - slopeBefore) < 0.00005,
            "Paper stock \(stock) channel \(channel) has a small-slope jump")
        }
      }
    }
    print("Metal film rendering checks passed")
  }
}

import CoreImage

struct PreviewRequest: @unchecked Sendable {
  let image: CIImage
  let scale: CGFloat
  let sourceURL: URL?
  let originalImage: CIImage?
  let showGamutWarning: Bool
  let highPrecision: Bool
  let displayP3: Bool
  let compressSRGBGamut: Bool

  init(
    image: CIImage, scale: CGFloat, sourceURL: URL?, originalImage: CIImage?,
    showGamutWarning: Bool, highPrecision: Bool = false, displayP3: Bool = false,
    compressSRGBGamut: Bool = false
  ) {
    self.image = image
    self.scale = scale
    self.sourceURL = sourceURL
    self.originalImage = originalImage
    self.showGamutWarning = showGamutWarning
    self.highPrecision = highPrecision
    self.displayP3 = displayP3
    self.compressSRGBGamut = compressSRGBGamut
  }
}

struct PreviewResult: @unchecked Sendable {
  let image: CGImage
  let original: CGImage?
  let histogram: PreviewHistogram?
}

struct PreviewHistogram: Sendable {
  let displayP3: Bool
  let bins: [Double]
  let redBins: [Double]
  let greenBins: [Double]
  let blueBins: [Double]
  let blackFraction: Double
  let whiteFraction: Double
  let redNearWhiteFraction: Double
  let greenNearWhiteFraction: Double
  let blueNearWhiteFraction: Double
  let outsideSRGBFraction: Double
  let waveform: WaveformDistribution
  let redWaveform: WaveformDistribution
  let greenWaveform: WaveformDistribution
  let blueWaveform: WaveformDistribution
}

struct WaveformDistribution: Sendable {
  static let columns = 64
  static let levels = 64
  let intensities: [Double]

  static func make(
    from pixels: [UInt8], width: Int, height: Int, component: Int? = nil,
    displayP3: Bool = false
  ) -> WaveformDistribution {
    var counts = [Int](repeating: 0, count: columns * levels)
    let validComponent = component.map { (0...2).contains($0) } ?? true
    guard width > 0, height > 0, pixels.count >= width * height * 4, validComponent
    else {
      return WaveformDistribution(intensities: counts.map { _ in 0 })
    }
    for index in 0..<(width * height) {
      let offset = index * 4
      guard pixels[offset + 3] != 0 else { continue }
      let value: Double
      if let component {
        value = Double(pixels[offset + component])
      } else {
        let weights = displayP3 ? (0.22897, 0.69174, 0.07929) : (0.2126, 0.7152, 0.0722)
        value =
          weights.0 * Double(pixels[offset]) + weights.1 * Double(pixels[offset + 1])
          + weights.2 * Double(pixels[offset + 2])
      }
      let column = min(columns - 1, index % width * columns / width)
      let level = min(levels - 1, Int(value * Double(levels) / 256))
      counts[level * columns + column] += 1
    }
    let peak = Double(max(1, counts.max() ?? 0))
    return WaveformDistribution(
      intensities: counts.map { $0 == 0 ? 0 : log1p(Double($0)) / log1p(peak) })
  }
}

actor PreviewRenderer {
  private let gamutWarningKernel = FilmKernels.kernel("outputGamutWarning")
  private let halfContext = CIContext(options: [
    .useSoftwareRenderer: false,
    .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
    .workingFormat: CIFormat.RGBAh,
  ])
  private let floatContext = CIContext(options: [
    .useSoftwareRenderer: false,
    .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
    .workingFormat: CIFormat.RGBAf,
  ])

  func render(_ request: PreviewRequest) -> PreviewResult? {
    let accessing = request.sourceURL?.startAccessingSecurityScopedResource() ?? false
    defer { if accessing { request.sourceURL?.stopAccessingSecurityScopedResource() } }
    guard !Task.isCancelled else { return nil }
    let context = request.highPrecision ? floatContext : halfContext
    let scopedImage: CIImage
    if request.compressSRGBGamut && !request.displayP3 {
      guard let mapped = OutputGamutMap.apply(to: request.image) else { return nil }
      scopedImage = mapped
    } else {
      scopedImage = request.image
    }
    let displayImage: CIImage
    if request.showGamutWarning {
      guard let gamutWarningKernel,
        let highlighted = gamutWarningKernel.apply(
          extent: request.image.extent, arguments: [request.image])
      else { return nil }
      displayImage = highlighted
    } else {
      displayImage = request.displayP3 ? request.image : scopedImage
    }
    let canvasSpace = CGColorSpace(
      name: request.displayP3 ? CGColorSpace.displayP3 : CGColorSpace.sRGB)!
    guard
      let image = renderImage(
        displayImage, scale: request.scale, context: context, colorSpace: canvasSpace,
        highPrecision: request.highPrecision)
    else {
      return nil
    }
    let original = request.originalImage.flatMap {
      renderImage(
        $0, scale: request.scale, context: context, colorSpace: canvasSpace,
        highPrecision: request.highPrecision)
    }
    guard !Task.isCancelled, request.originalImage == nil || original != nil else { return nil }
    return PreviewResult(
      image: image, original: original,
      histogram: histogram(
        for: request.displayP3 ? request.image : scopedImage,
        gamutSource: request.image, context: context, displayP3: request.displayP3))
  }

  private func histogram(
    for source: CIImage, gamutSource: CIImage, context: CIContext, displayP3: Bool
  ) -> PreviewHistogram? {
    let scale = min(1, 256 / max(source.extent.width, source.extent.height))
    let reduced = downsampled(source, scale: scale)
    let bounds = reduced.extent.integral
    let width = Int(bounds.width)
    let height = Int(bounds.height)
    guard width > 0, height > 0, !Task.isCancelled else { return nil }
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    pixels.withUnsafeMutableBytes { bytes in
      if let base = bytes.baseAddress {
        context.render(
          reduced, toBitmap: base, rowBytes: width * 4, bounds: bounds,
          format: .RGBA8,
          colorSpace: CGColorSpace(name: displayP3 ? CGColorSpace.displayP3 : CGColorSpace.sRGB)!)
      }
    }
    var counts = [Int](repeating: 0, count: 64)
    var redCounts = [Int](repeating: 0, count: 64)
    var greenCounts = [Int](repeating: 0, count: 64)
    var blueCounts = [Int](repeating: 0, count: 64)
    var black = 0
    var white = 0
    var redNearWhite = 0
    var greenNearWhite = 0
    var blueNearWhite = 0
    var visibleCount = 0
    let lumaWeights = displayP3 ? (0.22897, 0.69174, 0.07929) : (0.2126, 0.7152, 0.0722)
    for offset in stride(from: 0, to: pixels.count, by: 4) {
      guard pixels[offset + 3] != 0 else { continue }
      visibleCount += 1
      let red = pixels[offset]
      let green = pixels[offset + 1]
      let blue = pixels[offset + 2]
      let luminance =
        lumaWeights.0 * Double(red) + lumaWeights.1 * Double(green)
        + lumaWeights.2 * Double(blue)
      counts[min(63, Int(luminance / 4))] += 1
      redCounts[min(63, Int(red) / 4)] += 1
      greenCounts[min(63, Int(green) / 4)] += 1
      blueCounts[min(63, Int(blue) / 4)] += 1
      if luminance <= 4 { black += 1 }
      if luminance >= 251 { white += 1 }
      if red >= 251 { redNearWhite += 1 }
      if green >= 251 { greenNearWhite += 1 }
      if blue >= 251 { blueNearWhite += 1 }
    }
    guard visibleCount > 0 else { return nil }
    let peak = Double(
      [
        1, counts.max() ?? 0, redCounts.max() ?? 0,
        greenCounts.max() ?? 0, blueCounts.max() ?? 0,
      ].max()!)
    let total = Double(visibleCount)
    var linearPixels = [Float](repeating: 0, count: width * height * 4)
    let gamutReduced = downsampled(gamutSource, scale: scale)
    linearPixels.withUnsafeMutableBytes { bytes in
      if let base = bytes.baseAddress {
        context.render(
          gamutReduced, toBitmap: base, rowBytes: width * 4 * MemoryLayout<Float>.size,
          bounds: bounds, format: .RGBAf,
          colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!)
      }
    }
    var outside = 0
    for offset in stride(from: 0, to: linearPixels.count, by: 4) {
      guard pixels[offset + 3] != 0 else { continue }
      let channels = linearPixels[offset..<(offset + 3)]
      if channels.contains(where: { !$0.isFinite || $0 < -0.0001 || $0 > 1.0001 }) {
        outside += 1
      }
    }
    return PreviewHistogram(
      displayP3: displayP3,
      bins: counts.map { Double($0) / peak },
      redBins: redCounts.map { Double($0) / peak },
      greenBins: greenCounts.map { Double($0) / peak },
      blueBins: blueCounts.map { Double($0) / peak },
      blackFraction: Double(black) / total,
      whiteFraction: Double(white) / total,
      redNearWhiteFraction: Double(redNearWhite) / total,
      greenNearWhiteFraction: Double(greenNearWhite) / total,
      blueNearWhiteFraction: Double(blueNearWhite) / total,
      outsideSRGBFraction: Double(outside) / total,
      waveform: WaveformDistribution.make(
        from: pixels, width: width, height: height, displayP3: displayP3),
      redWaveform: WaveformDistribution.make(
        from: pixels, width: width, height: height, component: 0),
      greenWaveform: WaveformDistribution.make(
        from: pixels, width: width, height: height, component: 1),
      blueWaveform: WaveformDistribution.make(
        from: pixels, width: width, height: height, component: 2)
    )
  }

  private func renderImage(
    _ source: CIImage, scale: CGFloat, context: CIContext, colorSpace: CGColorSpace,
    highPrecision: Bool
  ) -> CGImage? {
    let reduced = downsampled(source, scale: scale)
    guard !Task.isCancelled else { return nil }
    return context.createCGImage(
      reduced, from: reduced.extent, format: highPrecision ? .RGBA16 : .RGBA8,
      colorSpace: colorSpace)
  }

  private func downsampled(_ source: CIImage, scale: CGFloat) -> CIImage {
    guard scale < 1 else { return source }
    return source.applyingFilter(
      "CILanczosScaleTransform",
      parameters: [kCIInputScaleKey: scale, kCIInputAspectRatioKey: 1])
  }
}

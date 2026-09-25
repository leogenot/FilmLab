import CoreImage

struct PreviewRequest: @unchecked Sendable {
  let image: CIImage
  let scale: CGFloat
  let sourceURL: URL?
  let originalImage: CIImage?
  let showGamutWarning: Bool
}

struct PreviewResult: @unchecked Sendable {
  let image: CGImage
  let original: CGImage?
  let histogram: PreviewHistogram?
}

struct PreviewHistogram: Sendable {
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
}

actor PreviewRenderer {
  private let gamutWarningKernel = FilmKernels.kernel("outputGamutWarning")
  private let context = CIContext(options: [
    .useSoftwareRenderer: false,
    .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
    .workingFormat: CIFormat.RGBAh,
  ])

  func render(_ request: PreviewRequest) -> PreviewResult? {
    let accessing = request.sourceURL?.startAccessingSecurityScopedResource() ?? false
    defer { if accessing { request.sourceURL?.stopAccessingSecurityScopedResource() } }
    guard !Task.isCancelled else { return nil }
    let displayImage: CIImage
    if request.showGamutWarning {
      guard let gamutWarningKernel,
        let highlighted = gamutWarningKernel.apply(
          extent: request.image.extent, arguments: [request.image])
      else { return nil }
      displayImage = highlighted
    } else {
      displayImage = request.image
    }
    guard let image = renderImage(displayImage, scale: request.scale) else { return nil }
    let original = request.originalImage.flatMap { renderImage($0, scale: request.scale) }
    guard !Task.isCancelled, request.originalImage == nil || original != nil else { return nil }
    return PreviewResult(image: image, original: original, histogram: histogram(for: request.image))
  }

  private func histogram(for source: CIImage) -> PreviewHistogram? {
    let scale = min(1, 256 / max(source.extent.width, source.extent.height))
    let reduced = source.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    let bounds = reduced.extent.integral
    let width = Int(bounds.width)
    let height = Int(bounds.height)
    guard width > 0, height > 0, !Task.isCancelled else { return nil }
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    pixels.withUnsafeMutableBytes { bytes in
      if let base = bytes.baseAddress {
        context.render(
          reduced, toBitmap: base, rowBytes: width * 4, bounds: bounds,
          format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
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
    for offset in stride(from: 0, to: pixels.count, by: 4) {
      let red = pixels[offset]
      let green = pixels[offset + 1]
      let blue = pixels[offset + 2]
      let luminance =
        0.2126 * Double(red) + 0.7152 * Double(green)
        + 0.0722 * Double(blue)
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
    let peak = Double(
      [
        1, counts.max() ?? 0, redCounts.max() ?? 0,
        greenCounts.max() ?? 0, blueCounts.max() ?? 0,
      ].max()!)
    let total = Double(width * height)
    var linearPixels = [Float](repeating: 0, count: width * height * 4)
    linearPixels.withUnsafeMutableBytes { bytes in
      if let base = bytes.baseAddress {
        context.render(
          reduced, toBitmap: base, rowBytes: width * 4 * MemoryLayout<Float>.size,
          bounds: bounds, format: .RGBAf,
          colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!)
      }
    }
    var outside = 0
    for offset in stride(from: 0, to: linearPixels.count, by: 4) {
      let channels = linearPixels[offset..<(offset + 3)]
      if channels.contains(where: { !$0.isFinite || $0 < -0.0001 || $0 > 1.0001 }) {
        outside += 1
      }
    }
    return PreviewHistogram(
      bins: counts.map { Double($0) / peak },
      redBins: redCounts.map { Double($0) / peak },
      greenBins: greenCounts.map { Double($0) / peak },
      blueBins: blueCounts.map { Double($0) / peak },
      blackFraction: Double(black) / total,
      whiteFraction: Double(white) / total,
      redNearWhiteFraction: Double(redNearWhite) / total,
      greenNearWhiteFraction: Double(greenNearWhite) / total,
      blueNearWhiteFraction: Double(blueNearWhite) / total,
      outsideSRGBFraction: Double(outside) / total
    )
  }

  private func renderImage(_ source: CIImage, scale: CGFloat) -> CGImage? {
    let reduced = source.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    guard !Task.isCancelled else { return nil }
    return context.createCGImage(
      reduced, from: reduced.extent, format: .RGBA8,
      colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
  }
}

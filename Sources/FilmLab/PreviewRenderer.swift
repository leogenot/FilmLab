import CoreImage

struct PreviewRequest: @unchecked Sendable {
  let image: CIImage
  let scale: CGFloat
  let sourceURL: URL?
  let originalImage: CIImage?
}

struct PreviewResult: @unchecked Sendable {
  let image: CGImage
  let original: CGImage?
  let histogram: PreviewHistogram?
}

struct PreviewHistogram: Sendable {
  let bins: [Double]
  let blackFraction: Double
  let whiteFraction: Double
}

actor PreviewRenderer {
  private let context = CIContext(options: [
    .useSoftwareRenderer: false,
    .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
    .workingFormat: CIFormat.RGBAh,
  ])

  func render(_ request: PreviewRequest) -> PreviewResult? {
    let accessing = request.sourceURL?.startAccessingSecurityScopedResource() ?? false
    defer { if accessing { request.sourceURL?.stopAccessingSecurityScopedResource() } }
    guard !Task.isCancelled else { return nil }
    guard let image = renderImage(request.image, scale: request.scale) else { return nil }
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
    var black = 0
    var white = 0
    for offset in stride(from: 0, to: pixels.count, by: 4) {
      let luminance =
        0.2126 * Double(pixels[offset]) + 0.7152 * Double(pixels[offset + 1])
        + 0.0722 * Double(pixels[offset + 2])
      counts[min(63, Int(luminance / 4))] += 1
      if luminance <= 4 { black += 1 }
      if luminance >= 251 { white += 1 }
    }
    let peak = max(1, counts.max() ?? 1)
    let total = Double(width * height)
    return PreviewHistogram(
      bins: counts.map { Double($0) / Double(peak) },
      blackFraction: Double(black) / total,
      whiteFraction: Double(white) / total
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

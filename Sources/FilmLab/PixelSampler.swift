import CoreImage

struct LinearRGB: Sendable {
  let red: Double
  let green: Double
  let blue: Double

  var luminance: Double { 0.2126 * red + 0.7152 * green + 0.0722 * blue }

  var stopsFromMiddleGray: Double {
    log2(max(luminance, 0.000001) / 0.18)
  }

  var hueDegrees: Double? {
    let r = max(red, 0)
    let g = max(green, 0)
    let b = max(blue, 0)
    let peak = max(r, g, b)
    let chroma = peak - min(r, g, b)
    guard peak >= 0.002, chroma / peak >= 0.02 else { return nil }
    let sector: Double
    if peak == r {
      sector = (g - b) / chroma
    } else if peak == g {
      sector = (b - r) / chroma + 2
    } else {
      sector = (r - g) / chroma + 4
    }
    let hue = sector * 60
    return hue < 0 ? hue + 360 : hue
  }
}

struct PixelReadout: Sendable {
  let input: LinearRGB
  let output: LinearRGB
  let displayX: Double
  let displayY: Double
}

struct PixelSampleRequest: @unchecked Sendable {
  let input: CIImage
  let output: CIImage
  let inputLocation: CGPoint
  let displayX: Double
  let displayY: Double
  let sourceURL: URL?
}

actor PixelSampler {
  private let colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
  private let context = CIContext(options: [
    .useSoftwareRenderer: false,
    .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
    .workingFormat: CIFormat.RGBAf,
  ])

  func sample(_ request: PixelSampleRequest) -> PixelReadout? {
    let accessing = request.sourceURL?.startAccessingSecurityScopedResource() ?? false
    defer { if accessing { request.sourceURL?.stopAccessingSecurityScopedResource() } }
    guard !Task.isCancelled,
      let input = read(
        request.input, x: Double(request.inputLocation.x), y: Double(request.inputLocation.y)),
      let output = read(request.output, x: request.displayX, y: 1 - request.displayY),
      !Task.isCancelled
    else { return nil }
    return PixelReadout(
      input: input, output: output,
      displayX: request.displayX, displayY: request.displayY)
  }

  func sampleInput(_ request: PixelSampleRequest) -> LinearRGB? {
    let accessing = request.sourceURL?.startAccessingSecurityScopedResource() ?? false
    defer { if accessing { request.sourceURL?.stopAccessingSecurityScopedResource() } }
    guard !Task.isCancelled else { return nil }
    return read(
      request.input, x: Double(request.inputLocation.x), y: Double(request.inputLocation.y))
  }

  private func read(_ image: CIImage, x: Double, y: Double) -> LinearRGB? {
    let extent = image.extent
    guard extent.width > 0, extent.height > 0,
      (0...1).contains(x), (0...1).contains(y)
    else { return nil }
    let column = min(
      max(floor(extent.minX + extent.width * x), floor(extent.minX)), ceil(extent.maxX) - 1)
    let row = min(
      max(floor(extent.minY + extent.height * y), floor(extent.minY)), ceil(extent.maxY) - 1)
    let bounds = CGRect(x: column, y: row, width: 1, height: 1)
    var pixels = [Float](repeating: 0, count: 4)
    pixels.withUnsafeMutableBytes { bytes in
      if let base = bytes.baseAddress {
        context.render(
          image, toBitmap: base, rowBytes: 4 * MemoryLayout<Float>.size,
          bounds: bounds, format: .RGBAf, colorSpace: colorSpace)
      }
    }
    guard pixels.prefix(3).allSatisfy(\.isFinite) else { return nil }
    return LinearRGB(red: Double(pixels[0]), green: Double(pixels[1]), blue: Double(pixels[2]))
  }
}

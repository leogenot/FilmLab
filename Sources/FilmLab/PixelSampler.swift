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

struct LocalRangeRequest: @unchecked Sendable {
  let image: CIImage
  let location: CGPoint
  let sourceURL: URL?
}

struct LocalRangeSample: Sendable {
  let toneStops: Double
  let hueDegrees: Double?

  static func summarize(_ pixels: [LinearRGB], centerIndex: Int) -> LocalRangeSample? {
    guard pixels.indices.contains(centerIndex), !pixels.isEmpty else { return nil }
    let center = pixels[centerIndex]
    guard center.red.isFinite, center.green.isFinite, center.blue.isFinite else { return nil }
    let stops = pixels.filter {
      $0.red.isFinite && $0.green.isFinite && $0.blue.isFinite
    }.map(\.stopsFromMiddleGray).sorted()
    guard !stops.isEmpty else { return nil }
    let tone =
      stops.count.isMultiple(of: 2)
      ? (stops[stops.count / 2 - 1] + stops[stops.count / 2]) / 2
      : stops[stops.count / 2]
    guard let centerHue = center.hueDegrees else {
      return LocalRangeSample(toneStops: tone, hueDegrees: nil)
    }
    var horizontal = 0.0
    var vertical = 0.0
    for pixel in pixels {
      guard pixel.red.isFinite, pixel.green.isFinite, pixel.blue.isFinite,
        let hue = pixel.hueDegrees
      else { continue }
      let distance = abs(hue - centerHue)
      guard min(distance, 360 - distance) <= 35 else { continue }
      let radians = hue * .pi / 180
      horizontal += cos(radians)
      vertical += sin(radians)
    }
    let average = atan2(vertical, horizontal) * 180 / .pi
    let wrapped = (average + 360).truncatingRemainder(dividingBy: 360)
    return LocalRangeSample(toneStops: tone, hueDegrees: wrapped > 359.999999999 ? 0 : wrapped)
  }
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

  func sampleLocalRange(_ request: LocalRangeRequest) -> LocalRangeSample? {
    let accessing = request.sourceURL?.startAccessingSecurityScopedResource() ?? false
    defer { if accessing { request.sourceURL?.stopAccessingSecurityScopedResource() } }
    guard !Task.isCancelled else { return nil }
    let extent = request.image.extent
    guard extent.width > 0, extent.height > 0,
      (0...1).contains(request.location.x), (0...1).contains(request.location.y)
    else { return nil }
    let column = Int(
      min(
        max(
          floor(extent.minX + extent.width * request.location.x), floor(extent.minX)),
        ceil(extent.maxX) - 1))
    let row = Int(
      min(
        max(
          floor(extent.minY + extent.height * request.location.y), floor(extent.minY)),
        ceil(extent.maxY) - 1))
    let minColumn = max(Int(floor(extent.minX)), column - 3)
    let maxColumn = min(Int(ceil(extent.maxX)) - 1, column + 3)
    let minRow = max(Int(floor(extent.minY)), row - 3)
    let maxRow = min(Int(ceil(extent.maxY)) - 1, row + 3)
    let width = maxColumn - minColumn + 1
    let height = maxRow - minRow + 1
    let bounds = CGRect(x: minColumn, y: minRow, width: width, height: height)
    var values = [Float](repeating: 0, count: width * height * 4)
    values.withUnsafeMutableBytes { bytes in
      if let base = bytes.baseAddress {
        context.render(
          request.image, toBitmap: base, rowBytes: width * 4 * MemoryLayout<Float>.size,
          bounds: bounds, format: .RGBAf, colorSpace: colorSpace)
      }
    }
    guard !Task.isCancelled else { return nil }
    let pixels = stride(from: 0, to: values.count, by: 4).map { index in
      LinearRGB(
        red: Double(values[index]), green: Double(values[index + 1]),
        blue: Double(values[index + 2]))
    }
    let centerIndex = (row - minRow) * width + column - minColumn
    return LocalRangeSample.summarize(pixels, centerIndex: centerIndex)
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

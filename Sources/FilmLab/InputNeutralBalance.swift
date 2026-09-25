import CoreImage
import CoreImage.CIFilterBuiltins

struct InputNeutralBalance: Codable, Equatable, Sendable {
  var red = 1.0
  var green = 1.0
  var blue = 1.0

  var isNeutral: Bool {
    abs(red - 1) < 0.000001 && abs(green - 1) < 0.000001 && abs(blue - 1) < 0.000001
  }

  static func fromSample(red: Double, green: Double, blue: Double) -> Self? {
    let channels = [red, green, blue]
    guard channels.allSatisfy(\.isFinite),
      channels.allSatisfy({ $0 > 0.005 && $0 < 0.98 })
    else { return nil }
    let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
    let gains = channels.map { luminance / $0 }
    guard gains.allSatisfy({ (0.25...4).contains($0) }) else { return nil }
    return Self(red: gains[0], green: gains[1], blue: gains[2])
  }

  func apply(to image: CIImage) -> CIImage {
    guard !isNeutral else { return image }
    let matrix = CIFilter.colorMatrix()
    matrix.inputImage = image
    matrix.rVector = CIVector(x: red, y: 0, z: 0, w: 0)
    matrix.gVector = CIVector(x: 0, y: green, z: 0, w: 0)
    matrix.bVector = CIVector(x: 0, y: 0, z: blue, w: 0)
    return matrix.outputImage ?? image
  }
}

struct NeutralSampleRequest: @unchecked Sendable {
  let image: CIImage
  let location: CGPoint
  let sourceURL: URL?
}

actor NeutralPatchSampler {
  private let colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
  private let context = CIContext(options: [
    .useSoftwareRenderer: false,
    .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
    .workingFormat: CIFormat.RGBAf,
  ])

  func sample(_ request: NeutralSampleRequest) -> InputNeutralBalance? {
    let accessing = request.sourceURL?.startAccessingSecurityScopedResource() ?? false
    defer { if accessing { request.sourceURL?.stopAccessingSecurityScopedResource() } }
    let extent = request.image.extent.integral
    guard !Task.isCancelled, extent.width > 0, extent.height > 0 else { return nil }
    let width = min(32, Int(extent.width))
    let height = min(32, Int(extent.height))
    let centerX = extent.minX + request.location.x * extent.width
    let centerY = extent.minY + request.location.y * extent.height
    let x = min(max(floor(centerX - CGFloat(width) / 2), extent.minX), extent.maxX - CGFloat(width))
    let y = min(
      max(floor(centerY - CGFloat(height) / 2), extent.minY), extent.maxY - CGFloat(height))
    let bounds = CGRect(x: x, y: y, width: CGFloat(width), height: CGFloat(height))
    var pixels = [Float](repeating: 0, count: width * height * 4)
    pixels.withUnsafeMutableBytes { bytes in
      if let base = bytes.baseAddress {
        context.render(
          request.image, toBitmap: base,
          rowBytes: width * 4 * MemoryLayout<Float>.size,
          bounds: bounds, format: .RGBAf, colorSpace: colorSpace)
      }
    }
    guard !Task.isCancelled else { return nil }
    var red = 0.0
    var green = 0.0
    var blue = 0.0
    var count = 0
    for offset in stride(from: 0, to: pixels.count, by: 4) {
      let channels = pixels[offset..<(offset + 3)]
      guard channels.allSatisfy(\.isFinite), pixels[offset + 3] > 0.5 else { continue }
      red += Double(pixels[offset])
      green += Double(pixels[offset + 1])
      blue += Double(pixels[offset + 2])
      count += 1
    }
    guard count > 0 else { return nil }
    return InputNeutralBalance.fromSample(
      red: red / Double(count), green: green / Double(count), blue: blue / Double(count))
  }
}

import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import UniformTypeIdentifiers

struct DecodedPhoto: @unchecked Sendable {
  let image: CIImage
  let cameraTemperature: Double?
  let cameraTint: Double?
  let highlightRecoverySupported: Bool
  let decoderSharpeningSupported: Bool
  let jpegChannelNearWhiteFraction: Double?
  let inputExposureRange: InputExposureRange?
}

actor ImageDecoder {
  private let diagnosticContext = CIContext(options: [
    .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
    .workingFormat: CIFormat.RGBAf,
  ])

  func isRAWFile(_ url: URL) -> Bool {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let identifier = CGImageSourceGetType(source) as String?,
      let type = UTType(identifier)
    else { return false }
    return type.conforms(to: .rawImage)
  }

  func decode(
    from url: URL, isRAW: Bool, flatRAW: Bool, highlightRecovery: Bool,
    decoderSharpening: Bool = true,
    temperature: Double?, tint: Double?, maxDimension: Int? = nil,
    includeDiagnostics: Bool = false
  ) throws -> DecodedPhoto {
    try Task.checkCancellation()
    if isRAW {
      guard let raw = CIRAWFilter(imageURL: url) else { throw EditorError.unsupported }
      let cameraTemperature = Double(raw.neutralTemperature)
      let cameraTint = Double(raw.neutralTint)
      var highlightRecoverySupported = false
      if #available(macOS 26.0, *) {
        highlightRecoverySupported = raw.isHighlightRecoverySupported
        if highlightRecoverySupported { raw.isHighlightRecoveryEnabled = highlightRecovery }
      }
      if let temperature { raw.neutralTemperature = Float(temperature) }
      if let tint { raw.neutralTint = Float(tint) }
      if !decoderSharpening && raw.isSharpnessSupported { raw.sharpnessAmount = 0 }
      if flatRAW {
        raw.boostAmount = 0
        raw.boostShadowAmount = 0
        raw.localToneMapAmount = 0
      }
      if let maxDimension, maxDimension > 0 {
        let nativeLongestSide = max(raw.nativeSize.width, raw.nativeSize.height)
        if nativeLongestSide.isFinite, nativeLongestSide > CGFloat(maxDimension) {
          raw.scaleFactor = Float(CGFloat(maxDimension) / nativeLongestSide)
        }
      }
      guard let image = raw.outputImage else { throw EditorError.unsupported }
      try Task.checkCancellation()
      return DecodedPhoto(
        image: image, cameraTemperature: cameraTemperature, cameraTint: cameraTint,
        highlightRecoverySupported: highlightRecoverySupported,
        decoderSharpeningSupported: raw.isSharpnessSupported,
        jpegChannelNearWhiteFraction: nil,
        inputExposureRange: includeDiagnostics ? inputExposureRange(in: image) : nil)
    }
    guard let image = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else {
      throw EditorError.unsupported
    }
    try Task.checkCancellation()
    let isJPEG =
      CGImageSourceCreateWithURL(url as CFURL, nil)
      .flatMap { CGImageSourceGetType($0) as String? }
      .flatMap { UTType($0) }?.conforms(to: .jpeg) == true
    let nearWhiteFraction =
      includeDiagnostics && isJPEG
      ? jpegChannelNearWhiteFraction(in: image) : nil
    return DecodedPhoto(
      image: image, cameraTemperature: nil, cameraTint: nil,
      highlightRecoverySupported: false,
      decoderSharpeningSupported: false,
      jpegChannelNearWhiteFraction: nearWhiteFraction,
      inputExposureRange: includeDiagnostics ? inputExposureRange(in: image) : nil)
  }

  private func inputExposureRange(in image: CIImage) -> InputExposureRange? {
    let extent = image.extent
    guard extent.width.isFinite, extent.height.isFinite,
      extent.width > 0, extent.height > 0
    else { return nil }
    let scale = min(1, 256 / max(extent.width, extent.height))
    let reduced = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    let bounds = reduced.extent.integral
    let width = Int(bounds.width)
    let height = Int(bounds.height)
    guard width > 0, height > 0 else { return nil }
    var pixels = [Float](repeating: 0, count: width * height * 4)
    pixels.withUnsafeMutableBytes { bytes in
      diagnosticContext.render(
        reduced, toBitmap: bytes.baseAddress!, rowBytes: width * 4 * MemoryLayout<Float>.size,
        bounds: bounds, format: .RGBAf,
        colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!)
    }
    return InputExposureRange.make(from: pixels, width: width, height: height)
  }

  private func jpegChannelNearWhiteFraction(in image: CIImage) -> Double? {
    let extent = image.extent
    guard extent.width.isFinite, extent.height.isFinite,
      extent.width > 0, extent.height > 0
    else { return nil }
    let scale = min(1, 256 / max(extent.width, extent.height))
    let reduced = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    let bounds = reduced.extent.integral
    let width = Int(bounds.width)
    let height = Int(bounds.height)
    guard width > 0, height > 0 else { return nil }
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    pixels.withUnsafeMutableBytes { bytes in
      diagnosticContext.render(
        reduced, toBitmap: bytes.baseAddress!, rowBytes: width * 4, bounds: bounds,
        format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
    }
    let nearWhiteCount = stride(from: 0, to: pixels.count, by: 4).reduce(0) { count, index in
      count + (max(pixels[index], pixels[index + 1], pixels[index + 2]) >= 250 ? 1 : 0)
    }
    return Double(nearWhiteCount) / Double(width * height)
  }
}

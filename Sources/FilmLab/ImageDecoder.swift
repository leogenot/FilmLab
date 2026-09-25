import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import UniformTypeIdentifiers

struct DecodedPhoto: @unchecked Sendable {
  let image: CIImage
  let sourceFileInfo: SourceFileInfo
  let cameraTemperature: Double?
  let cameraTint: Double?
  let highlightRecoverySupported: Bool
  let decoderSharpeningSupported: Bool
  let luminanceNoiseReductionSupported: Bool
  let colorNoiseReductionSupported: Bool
  let jpegChannelNearWhiteFraction: Double?
  let inputExposureRange: InputExposureRange?
  let sourceLongestSide: CGFloat
}

struct SourceFileInfo: Sendable, Equatable {
  let reportedBitDepth: Int?
  let embeddedProfileName: String?

  static func read(from url: URL, isRAW: Bool) -> Self {
    let source = CGImageSourceCreateWithURL(
      url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary)
    let properties = source.flatMap {
      CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any]
    }
    return Self(properties: properties, isRAW: isRAW)
  }

  init(properties: [CFString: Any]?, isRAW: Bool) {
    let depth = (properties?[kCGImagePropertyDepth] as? NSNumber)?.intValue
    let profile = (properties?[kCGImagePropertyProfileName] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    reportedBitDepth = depth.flatMap { $0 > 0 ? $0 : nil }
    embeddedProfileName = isRAW || profile?.isEmpty != false ? nil : profile
  }
}

actor ImageDecoder {
  private let diagnosticContext = CIContext(options: [
    .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
    .workingFormat: CIFormat.RGBAf,
  ])

  func isRAWFile(_ url: URL) -> Bool {
    PhotoFileSupport.rawStatus(url) ?? false
  }

  func supportedRAWStatus(_ url: URL) -> Bool? {
    PhotoFileSupport.rawStatus(url)
  }

  func decode(
    from url: URL, isRAW: Bool, flatRAW: Bool, highlightRecovery: Bool,
    decoderSharpening: Bool = true,
    luminanceNoiseReduction: Bool = true, colorNoiseReduction: Bool = true,
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
      if !luminanceNoiseReduction && raw.isLuminanceNoiseReductionSupported {
        raw.luminanceNoiseReductionAmount = 0
      }
      if !colorNoiseReduction && raw.isColorNoiseReductionSupported {
        raw.colorNoiseReductionAmount = 0
      }
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
        image: image, sourceFileInfo: SourceFileInfo.read(from: url, isRAW: true),
        cameraTemperature: cameraTemperature, cameraTint: cameraTint,
        highlightRecoverySupported: highlightRecoverySupported,
        decoderSharpeningSupported: raw.isSharpnessSupported,
        luminanceNoiseReductionSupported: raw.isLuminanceNoiseReductionSupported,
        colorNoiseReductionSupported: raw.isColorNoiseReductionSupported,
        jpegChannelNearWhiteFraction: nil,
        inputExposureRange: includeDiagnostics ? inputExposureRange(in: image) : nil,
        sourceLongestSide: max(raw.nativeSize.width, raw.nativeSize.height))
    }
    let image: CIImage
    if let maxDimension, maxDimension > 0,
      let source = CGImageSourceCreateWithURL(
        url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
      let thumbnail = CGImageSourceCreateThumbnailAtIndex(
        source, 0,
        [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceCreateThumbnailWithTransform: true,
          kCGImageSourceThumbnailMaxPixelSize: maxDimension,
        ] as CFDictionary)
    {
      image = CIImage(cgImage: thumbnail)
    } else {
      guard
        let fullImage = CIImage(
          contentsOf: url, options: [.applyOrientationProperty: true])
      else { throw EditorError.unsupported }
      image = fullImage
    }
    try Task.checkCancellation()
    let imageSource = CGImageSourceCreateWithURL(
      url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary)
    let isJPEG =
      imageSource
      .flatMap { CGImageSourceGetType($0) as String? }
      .flatMap { UTType($0) }?.conforms(to: .jpeg) == true
    let properties = imageSource.flatMap {
      CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any]
    }
    let nativeWidth = (properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue
    let nativeHeight = (properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue
    let nativeLongest = max(nativeWidth ?? 0, nativeHeight ?? 0)
    let nearWhiteFraction =
      includeDiagnostics && isJPEG
      ? jpegChannelNearWhiteFraction(in: image) : nil
    return DecodedPhoto(
      image: image, sourceFileInfo: SourceFileInfo(properties: properties, isRAW: false),
      cameraTemperature: nil, cameraTint: nil,
      highlightRecoverySupported: false,
      decoderSharpeningSupported: false,
      luminanceNoiseReductionSupported: false,
      colorNoiseReductionSupported: false,
      jpegChannelNearWhiteFraction: nearWhiteFraction,
      inputExposureRange: includeDiagnostics ? inputExposureRange(in: image) : nil,
      sourceLongestSide: nativeLongest > 0
        ? nativeLongest : max(image.extent.width, image.extent.height))
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

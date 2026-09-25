import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import UniformTypeIdentifiers

struct DecodedPhoto: @unchecked Sendable {
  let image: CIImage
  let cameraTemperature: Double?
  let cameraTint: Double?
  let highlightRecoverySupported: Bool
}

actor ImageDecoder {
  func isRAWFile(_ url: URL) -> Bool {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let identifier = CGImageSourceGetType(source) as String?,
      let type = UTType(identifier)
    else { return false }
    return type.conforms(to: .rawImage)
  }

  func decode(
    from url: URL, isRAW: Bool, flatRAW: Bool, highlightRecovery: Bool,
    temperature: Double?, tint: Double?
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
      if flatRAW {
        raw.boostAmount = 0
        raw.boostShadowAmount = 0
        raw.localToneMapAmount = 0
      }
      guard let image = raw.outputImage else { throw EditorError.unsupported }
      try Task.checkCancellation()
      return DecodedPhoto(
        image: image, cameraTemperature: cameraTemperature, cameraTint: cameraTint,
        highlightRecoverySupported: highlightRecoverySupported)
    }
    guard let image = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else {
      throw EditorError.unsupported
    }
    try Task.checkCancellation()
    return DecodedPhoto(
      image: image, cameraTemperature: nil, cameraTint: nil,
      highlightRecoverySupported: false)
  }
}

import CoreImage
import Foundation
import ImageIO

enum EditorError: Error {
  case unsupported
}

@main
struct ImageDecoderProbe {
  static func main() async throws {
    let linear = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
    let output = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CIContext(options: [.workingColorSpace: linear, .workingFormat: CIFormat.RGBAf])
    let first = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5, colorSpace: linear)!)
      .cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
    let second = CIImage(color: CIColor(red: 0.5005, green: 0.5, blue: 0.5, colorSpace: linear)!)
      .cropped(to: CGRect(x: 1, y: 0, width: 1, height: 1))
    let source = first.composited(over: second)
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLabDecoderProbe-\(UUID().uuidString).tiff")
    defer { try? FileManager.default.removeItem(at: url) }
    try context.writeTIFFRepresentation(
      of: source, to: url, format: .RGBA16, colorSpace: output, options: [:])

    guard let file = CGImageSourceCreateWithURL(url as CFURL, nil),
      let metadata = CGImageSourceCopyPropertiesAtIndex(file, 0, nil) as? [String: Any]
    else { preconditionFailure("TIFF fixture is unreadable") }
    precondition(metadata[kCGImagePropertyDepth as String] as? Int == 16)

    let decoded = try await ImageDecoder().decode(
      from: url, isRAW: false, flatRAW: false, highlightRecovery: false,
      temperature: nil, tint: nil)
    precondition(decoded.image.extent.size == CGSize(width: 2, height: 1))
    var pixels = [Float](repeating: 0, count: 8)
    pixels.withUnsafeMutableBytes { bytes in
      context.render(
        decoded.image, toBitmap: bytes.baseAddress!, rowBytes: 32,
        bounds: CGRect(x: 0, y: 0, width: 2, height: 1), format: .RGBAf,
        colorSpace: linear)
    }
    let difference = pixels[4] - pixels[0]
    precondition(difference > 0.0002 && difference < 0.001, "16-bit input was quantized")
    precondition(decoded.jpegChannelNearWhiteFraction == nil, "TIFF reported JPEG headroom")
    print("File-backed 16-bit TIFF decode retained sub-8-bit detail: \(difference)")

    let gray = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5, colorSpace: linear)!)
      .cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))
    let white = CIImage(color: CIColor(red: 1, green: 1, blue: 1, colorSpace: linear)!)
      .cropped(to: CGRect(x: 64, y: 0, width: 64, height: 64))
    let jpegURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLabDecoderProbe-\(UUID().uuidString).jpg")
    defer { try? FileManager.default.removeItem(at: jpegURL) }
    guard
      let jpegData = context.jpegRepresentation(
        of: gray.composited(over: white), colorSpace: output, options: [:])
    else { preconditionFailure("JPEG fixture could not be encoded") }
    try jpegData.write(to: jpegURL)
    let jpeg = try await ImageDecoder().decode(
      from: jpegURL, isRAW: false, flatRAW: false, highlightRecovery: false,
      temperature: nil, tint: nil)
    guard let fraction = jpeg.jpegChannelNearWhiteFraction else {
      preconditionFailure("JPEG headroom was not reported")
    }
    precondition((0.45...0.55).contains(fraction), "JPEG bright fraction did not reflect input")
    print("JPEG source channel headroom check passed: \(fraction)")
  }
}

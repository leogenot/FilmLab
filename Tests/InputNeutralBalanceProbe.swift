import CoreImage
import Foundation

@main
enum InputNeutralBalanceProbe {
  static func main() async {
    let sourcePixel: [Float] = [0.30, 0.40, 0.20, 1]
    let values = Array(repeating: sourcePixel, count: 16).flatMap { $0 }
    let image = values.withUnsafeBytes { bytes in
      CIImage(
        bitmapData: Data(bytes), bytesPerRow: 4 * 4 * MemoryLayout<Float>.size,
        size: CGSize(width: 4, height: 4), format: .RGBAf,
        colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
      ).transformed(by: CGAffineTransform(translationX: 10, y: 20))
    }
    let balance = await NeutralPatchSampler().sample(
      NeutralSampleRequest(image: image, location: CGPoint(x: 0.5, y: 0.5), sourceURL: nil))
    guard let balance else { fatalError("Valid neutral patch was rejected") }
    let expectedLuminance = 0.2126 * 0.30 + 0.7152 * 0.40 + 0.0722 * 0.20
    precondition(abs(balance.red * 0.30 - expectedLuminance) < 0.00001)
    precondition(abs(balance.green * 0.40 - expectedLuminance) < 0.00001)
    precondition(abs(balance.blue * 0.20 - expectedLuminance) < 0.00001)
    let corrected = balance.apply(to: image)
    var pixel = [Float](repeating: 0, count: 4)
    let context = CIContext(options: [
      .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
      .workingFormat: CIFormat.RGBAf,
    ])
    pixel.withUnsafeMutableBytes { bytes in
      context.render(
        corrected, toBitmap: bytes.baseAddress!,
        rowBytes: 4 * MemoryLayout<Float>.size,
        bounds: CGRect(x: 11, y: 21, width: 1, height: 1), format: .RGBAf,
        colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!)
    }
    precondition(abs(Double(pixel[0]) - expectedLuminance) < 0.0001)
    precondition(abs(pixel[0] - pixel[1]) < 0.0001)
    precondition(abs(pixel[1] - pixel[2]) < 0.0001)
    precondition(InputNeutralBalance.fromSample(red: 0.001, green: 0.002, blue: 0.001) == nil)
    precondition(InputNeutralBalance.fromSample(red: 0.99, green: 0.99, blue: 0.99) == nil)
    precondition(InputNeutralBalance.fromSample(red: 0.01, green: 0.5, blue: 0.01) == nil)
    print("Neutral patch balance retained luminance and rejected unstable samples")
  }
}

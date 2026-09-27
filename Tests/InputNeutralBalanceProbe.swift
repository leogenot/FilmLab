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
    let mixed =
      Array(repeating: sourcePixel, count: 48)
      + Array(repeating: [Float(0.9), 0.05, 0.05, 1], count: 16)
    let mixedPixels = mixed.flatMap { $0 }
    let mixedImage = mixedPixels.withUnsafeBytes { bytes in
      CIImage(
        bitmapData: Data(bytes), bytesPerRow: 8 * 4 * MemoryLayout<Float>.size,
        size: CGSize(width: 8, height: 8), format: .RGBAf,
        colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!)
    }
    let robust = await NeutralPatchSampler().sample(
      NeutralSampleRequest(image: mixedImage, location: CGPoint(x: 0.5, y: 0.5), sourceURL: nil))
    guard let robust else { fatalError("Dominant neutral patch was rejected") }
    precondition(abs(robust.red - balance.red) < 0.0001)
    precondition(abs(robust.green - balance.green) < 0.0001)
    precondition(abs(robust.blue - balance.blue) < 0.0001)
    var brighterCenter = mixed
    brighterCenter[36] = [0.45, 0.60, 0.30, 1]
    let brighterCenterPixels = brighterCenter.flatMap { $0 }
    let brighterCenterImage = brighterCenterPixels.withUnsafeBytes { bytes in
      CIImage(
        bitmapData: Data(bytes), bytesPerRow: 8 * 4 * MemoryLayout<Float>.size,
        size: CGSize(width: 8, height: 8), format: .RGBAf,
        colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!)
    }
    let brighter = await NeutralPatchSampler().sample(
      NeutralSampleRequest(
        image: brighterCenterImage, location: CGPoint(x: 0.5, y: 0.5), sourceURL: nil))
    precondition(brighter != nil, "Picker rejected the same surface at a different brightness")
    var wrongCenter = mixed
    wrongCenter[36] = [0.9, 0.05, 0.05, 1]
    let wrongCenterPixels = wrongCenter.flatMap { $0 }
    let wrongCenterImage = wrongCenterPixels.withUnsafeBytes { bytes in
      CIImage(
        bitmapData: Data(bytes), bytesPerRow: 8 * 4 * MemoryLayout<Float>.size,
        size: CGSize(width: 8, height: 8), format: .RGBAf,
        colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!)
    }
    let rejected = await NeutralPatchSampler().sample(
      NeutralSampleRequest(
        image: wrongCenterImage, location: CGPoint(x: 0.5, y: 0.5), sourceURL: nil))
    precondition(rejected == nil, "Picker corrected a different surface than the clicked one")
    print("Neutral patch balance resisted colored contamination and rejected mismatched clicks")
  }
}

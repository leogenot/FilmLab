import CoreImage
import Foundation

@main
struct PreviewRendererProbe {
  static func main() async {
    let values: [Float] = [
      0.2, 0.3, 0.4, 1,
      1.25, 0.3, 0.4, 1,
    ]
    let image = values.withUnsafeBytes { bytes in
      CIImage(
        bitmapData: Data(bytes), bytesPerRow: 2 * 4 * MemoryLayout<Float>.size,
        size: CGSize(width: 2, height: 1), format: .RGBAf,
        colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!)
    }
    let result = await PreviewRenderer().render(
      PreviewRequest(image: image, scale: 1, sourceURL: nil, originalImage: nil))
    precondition(result?.image.width == 2)
    precondition(result?.histogram?.outsideSRGBFraction == 0.5)
    print("Extended-linear output gamut diagnostic passed")
  }
}

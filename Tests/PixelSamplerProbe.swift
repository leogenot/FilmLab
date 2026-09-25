import CoreImage
import Foundation

@main
enum PixelSamplerProbe {
  static func main() async {
    func image(_ values: [Float], offset: CGPoint) -> CIImage {
      let data = values.withUnsafeBytes { Data($0) }
      return CIImage(
        bitmapData: data, bytesPerRow: 4 * MemoryLayout<Float>.size,
        size: CGSize(width: 1, height: 1), format: .RGBAf,
        colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
      ).transformed(by: CGAffineTransform(translationX: offset.x, y: offset.y))
    }
    let input = image([0.5001, 1.25, 0.125, 1], offset: CGPoint(x: 10, y: 20))
    let output = image([0.5002, 0.75, 0.25, 1], offset: CGPoint(x: 30, y: 40))
    let sample = await PixelSampler().sample(
      PixelSampleRequest(
        input: input, output: output, inputLocation: CGPoint(x: 0.5, y: 0.5),
        displayX: 0.5, displayY: 0.5, sourceURL: nil))
    guard let sample,
      abs(sample.input.red - 0.5001) < 0.00005,
      abs(sample.output.red - 0.5002) < 0.00005,
      sample.output.red > sample.input.red,
      sample.input.green > 1,
      sample.output.green < 1
    else { fatalError("Floating-point linear sampling lost detail or range") }
    print("PixelSamplerProbe passed")
  }
}

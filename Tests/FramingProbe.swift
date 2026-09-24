import CoreImage
import Foundation

@main
struct FramingProbe {
  static func main() {
    let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
    let context = CIContext(options: [.workingColorSpace: space, .workingFormat: CIFormat.RGBAf])
    let source = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: 1))
      .cropped(to: CGRect(x: 0, y: 0, width: 300, height: 450))

    func framed(_ turns: Int = 0, _ degrees: Double = 0, _ aspect: Int = 0) -> CIImage {
      Framing.apply(
        to: source, quarterTurns: turns, straightenDegrees: degrees,
        aspect: aspect, offsetX: 0, offsetY: 0)
    }

    let unchanged = framed()
    precondition(unchanged.extent.width == 300 && unchanged.extent.height == 450)
    let rotated = framed(1)
    precondition(rotated.extent.width == 450 && rotated.extent.height == 300)

    for degrees in [-15.0, -7.5, 7.5, 15.0] {
      let result = framed(0, degrees)
      precondition(result.extent.width < 300 && result.extent.height < 450)
      precondition(abs(result.extent.width / result.extent.height - 2.0 / 3.0) < 0.005)
      for x in [result.extent.minX + 2, result.extent.maxX - 2] {
        for y in [result.extent.minY + 2, result.extent.maxY - 2] {
          var pixel = [Float](repeating: 0, count: 4)
          pixel.withUnsafeMutableBytes { bytes in
            context.render(
              result, toBitmap: bytes.baseAddress!, rowBytes: 16,
              bounds: CGRect(x: x, y: y, width: 1, height: 1), format: .RGBAf,
              colorSpace: space)
          }
          precondition(pixel[3] > 0.99, "Straighten exposed a transparent corner")
        }
      }
    }
    let square = framed(0, 10, 1)
    precondition(square.extent.width == square.extent.height)
    print("Framing geometry checks passed")
  }
}

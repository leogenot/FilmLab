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
    let freeCrop = FreeCrop(centerX: 0.5, centerY: 0.5, width: 0.5, height: 0.4)
    let freeform = Framing.apply(
      to: source, quarterTurns: 0, straightenDegrees: 0,
      aspect: 5, offsetX: 0, offsetY: 0, freeCrop: freeCrop)
    precondition(freeform.extent.width == 150 && freeform.extent.height == 180)
    let freePoint = Framing.sourceLocation(
      displayX: 0, displayY: 0, sourceExtent: source.extent,
      quarterTurns: 0, straightenDegrees: 0,
      aspect: 5, offsetX: 0, offsetY: 0, freeCrop: freeCrop)!
    precondition(abs(freePoint.x - 0.25) < 0.001)
    precondition(abs(freePoint.y - 0.7) < 0.001)
    let clamped = FreeCrop(centerX: 0.05, centerY: 0.95, width: 0.5, height: 0.4)
    precondition(clamped.normalizedBounds.minX == 0)
    precondition(abs(clamped.normalizedBounds.maxY - 1) < 0.001)
    let square = framed(0, 10, 1)
    precondition(square.extent.width == square.extent.height)
    let portrait = framed(0, 0, 6)
    precondition(portrait.extent.width == 300 && portrait.extent.height == 450)
    let tall = framed(0, 0, 7)
    precondition(tall.extent.width == 253 && tall.extent.height == 450)
    func sourceLocation(
      _ x: Double, _ y: Double, turns: Int = 0, degrees: Double = 0,
      aspect: Int = 0
    ) -> CGPoint {
      Framing.sourceLocation(
        displayX: x, displayY: y, sourceExtent: source.extent,
        quarterTurns: turns, straightenDegrees: degrees,
        aspect: aspect, offsetX: 0, offsetY: 0)!
    }
    let originalPoint = sourceLocation(0.2, 0.3)
    precondition(abs(originalPoint.x - 0.2) < 0.001)
    precondition(abs(originalPoint.y - 0.7) < 0.001)
    let turnedPoint = sourceLocation(0.25, 0.3, turns: 1)
    precondition(abs(turnedPoint.x - 0.7) < 0.001)
    precondition(abs(turnedPoint.y - 0.75) < 0.001)
    let flippedPoint = sourceLocation(0.2, 0.3, turns: 2)
    precondition(abs(flippedPoint.x - 0.8) < 0.001)
    precondition(abs(flippedPoint.y - 0.3) < 0.001)
    let clockwisePoint = sourceLocation(0.25, 0.3, turns: 3)
    precondition(abs(clockwisePoint.x - 0.3) < 0.001)
    precondition(abs(clockwisePoint.y - 0.25) < 0.001)
    let croppedPoint = sourceLocation(0.5, 0, aspect: 1)
    precondition(abs(croppedPoint.x - 0.5) < 0.001)
    precondition(abs(croppedPoint.y - 5.0 / 6.0) < 0.001)
    let tallPoint = sourceLocation(0, 0.5, aspect: 7)
    precondition(abs(tallPoint.x - 23.0 / 300.0) < 0.001)
    precondition(abs(tallPoint.y - 0.5) < 0.001)
    precondition(
      Framing.sourceLocation(
        displayX: 1.1, displayY: 0.5, sourceExtent: source.extent,
        quarterTurns: 0, straightenDegrees: 0,
        aspect: 0, offsetX: 0, offsetY: 0) == nil)
    print("Framing geometry checks passed")
  }
}

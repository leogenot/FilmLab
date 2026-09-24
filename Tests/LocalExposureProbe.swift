import CoreImage
import Foundation

@main
struct LocalExposureProbe {
  static func main() {
    let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
    let context = CIContext(options: [
      .workingColorSpace: space, .workingFormat: CIFormat.RGBAf,
    ])
    let source = CIImage(color: CIColor(red: 0.18, green: 0.18, blue: 0.18, colorSpace: space)!)
      .cropped(to: CGRect(x: 0, y: 0, width: 101, height: 101))
    func red(_ image: CIImage, _ x: Int, _ y: Int) -> Float {
      var pixel = [Float](repeating: 0, count: 4)
      pixel.withUnsafeMutableBytes { bytes in
        context.render(
          image, toBitmap: bytes.baseAddress!, rowBytes: 16,
          bounds: CGRect(x: x, y: y, width: 1, height: 1), format: .RGBAf,
          colorSpace: space)
      }
      return pixel[0]
    }
    let mask = LocalExposure.mask(
      for: source, centerX: 0.8, centerY: 0.2, radius: 0.2, feather: 0.5)!
    precondition(red(mask, 80, 20) > 0.99, "Mask center is not white")
    precondition(red(mask, 20, 80) < 0.01, "Mask corner is not black")
    let unchanged = LocalExposure.apply(
      to: source, ev: 0, centerX: 0.5, centerY: 0.5, radius: 0.35, feather: 0.5)
    precondition(unchanged === source, "Zero EV should skip the local graph")
    let bright = LocalExposure.apply(
      to: source, ev: 1, centerX: 0.5, centerY: 0.5, radius: 0.35, feather: 0.5)
    precondition(red(bright, 50, 50) > 0.35, "Center did not gain a stop")
    precondition(abs(red(bright, 0, 0) - 0.18) < 0.002, "Corner changed")
    let moved = LocalExposure.apply(
      to: source, ev: -1, centerX: 0.8, centerY: 0.2, radius: 0.2, feather: 0.5)
    precondition(red(moved, 80, 20) < 0.1, "Moved center did not darken")
    precondition(abs(red(moved, 20, 80) - 0.18) < 0.002, "Moved mask spilled")
    print("Local scene-light checks passed")
  }
}

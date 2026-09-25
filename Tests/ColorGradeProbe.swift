import CoreImage
import Foundation

@main
struct ColorGradeProbe {
  static func main() {
    let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
    let context = CIContext(options: [
      .workingColorSpace: space,
      .workingFormat: CIFormat.RGBAf,
    ])
    let input = CIImage(color: CIColor(red: 0.3, green: 0.3, blue: 0.3, colorSpace: space)!)
      .cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
    func channels(_ image: CIImage) -> [Float] {
      var rgba = [Float](repeating: 0, count: 4)
      rgba.withUnsafeMutableBytes { bytes in
        context.render(
          image, toBitmap: bytes.baseAddress!, rowBytes: 16,
          bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
          format: .RGBAf, colorSpace: space)
      }
      return Array(rgba.prefix(3))
    }
    func grade(_ hue: Double, strength: Double = 1) -> [Float] {
      channels(
        ColorGrade.apply(
          to: input, shadowHue: 0, shadowStrength: 0,
          midHue: hue, midStrength: strength,
          highlightHue: 0, highlightStrength: 0))
    }
    precondition(grade(0, strength: 0).allSatisfy { abs($0 - 0.3) < 0.0001 })
    let red = grade(0)
    let green = grade(120)
    let blue = grade(240)
    precondition(red[0] > red[1] && red[1] == red[2])
    precondition(green[1] > green[0] && green[0] == green[2])
    precondition(blue[2] > blue[0] && blue[0] == blue[1])
    for graded in [red, green, blue] {
      let luminance = 0.2126 * graded[0] + 0.7152 * graded[1] + 0.0722 * graded[2]
      precondition(abs(luminance - 0.3) < 0.001)
    }
    precondition(zip(red, grade(360)).allSatisfy { abs($0 - $1) < 0.0001 })
    precondition(zip(blue, grade(-120)).allSatisfy { abs($0 - $1) < 0.0001 })
    let legacy = channels(
      ColorGrade.apply(
        to: input, shadowHue: 0, shadowStrength: 0,
        midHue: 240, midStrength: 1,
        highlightHue: 0, highlightStrength: 0,
        timingVersion: 1))
    let legacyLuminance = 0.2126 * legacy[0] + 0.7152 * legacy[1] + 0.0722 * legacy[2]
    precondition(legacy[2] > legacy[1] && legacy[1] > legacy[0])
    precondition(abs(legacyLuminance - 0.3) < 0.001)
    print("Deterministic tonal color vectors and luminance checks passed")
  }
}

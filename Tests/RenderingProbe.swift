import CoreImage
import Foundation

@main
struct RenderingProbe {
  static func main() {
    let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
    let context = CIContext(options: [
      .workingColorSpace: space,
      .workingFormat: CIFormat.RGBAf,
    ])
    let negative = FilmKernels.kernel("measuredNegative")!
    let positive = FilmKernels.kernel("portraPositive")!
    let sceneLight = FilmKernels.kernel("shapeSceneLight")!

    func patch(_ value: Double) -> CIImage {
      CIImage(color: CIColor(red: value, green: value, blue: value, colorSpace: space)!)
        .cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
    }

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

    func rendered(_ stock: Double, _ exposure: Double) -> [Float] {
      let source = patch(0.18)
      let density = negative.apply(
        extent: source.extent, arguments: [source, exposure, 0.0, stock])!
      let output = positive.apply(
        extent: source.extent,
        arguments: [density, source, exposure, 1.0, 0.0, 0.0, stock])!
      return channels(output)
    }

    for stock in [1.0, 2.0] {
      let under = rendered(stock, -2)
      let normal = rendered(stock, 0)
      let over = rendered(stock, 2)
      for channel in 0..<3 {
        precondition(
          under[channel] < normal[channel] && normal[channel] < over[channel],
          "Stock \(stock) has a reversed exposure response")
        precondition(
          abs(normal[channel] - 0.18) < 0.003,
          "Stock \(stock) lost neutral gray calibration")
      }
    }
    precondition(
      abs(rendered(1, 2)[0] - rendered(2, 2)[0]) > 0.01,
      "Portra and Ektar have indistinguishable bright response")

    func ektarPaper(_ paperExposure: Double) -> [Float] {
      let source = patch(0.18)
      let density = negative.apply(
        extent: source.extent, arguments: [source, 0.0, 0.0, 2.0])!
      return channels(
        positive.apply(
          extent: source.extent,
          arguments: [density, source, 0.0, 1.0, 1.0, paperExposure, 2.0])!)
    }
    let paperUnder = ektarPaper(-2)
    let paperNormal = ektarPaper(0)
    let paperOver = ektarPaper(2)
    for channel in 0..<3 {
      precondition(
        paperUnder[channel] > paperNormal[channel]
          && paperNormal[channel] > paperOver[channel],
        "Endura Premier paper exposure response is reversed")
      precondition(
        abs(paperNormal[channel] - 0.18) < 0.004,
        "Endura Premier reference gray is not neutral")
    }

    func shaped(_ light: Double, _ shadowEV: Double, _ highlightEV: Double) -> Float {
      let source = patch(light)
      return channels(
        sceneLight.apply(
          extent: source.extent, arguments: [source, shadowEV, highlightEV])!)[0]
    }
    precondition(
      shaped(0.018, 1, 0) > shaped(0.018, 0, 0) * 1.5,
      "Shadow light does not affect dark pixels")
    precondition(
      abs(shaped(0.18, 1, 0) - 0.18) < 0.001,
      "Shadow light shifted reference gray")
    precondition(
      shaped(1.8, 0, -1) < shaped(1.8, 0, 0) * 0.7,
      "Highlight light does not affect bright pixels")
    precondition(
      abs(shaped(0.18, 0, -1) - 0.18) < 0.001,
      "Highlight light shifted reference gray")
    var bands = Array(repeating: ColorMix(), count: 8)
    bands[0].saturation = -0.5
    func colorPatch(_ red: Double, _ green: Double, _ blue: Double) -> CIImage {
      CIImage(color: CIColor(red: red, green: green, blue: blue, colorSpace: space)!)
        .cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
    }
    let redPatch = colorPatch(0.8, 0.1, 0.08)
    let bluePatch = colorPatch(0.08, 0.2, 0.8)
    let grayPatch = patch(0.18)
    let redMixed = channels(ColorMixer.apply(to: redPatch, adjustments: bands))
    let blueMixed = channels(ColorMixer.apply(to: bluePatch, adjustments: bands))
    let grayMixed = channels(ColorMixer.apply(to: grayPatch, adjustments: bands))
    precondition(
      redMixed[0] - redMixed[2] < 0.8 - 0.08,
      "Red mixer saturation did not affect red pixels")
    precondition(
      abs(blueMixed[0] - 0.08) < 0.003 && abs(blueMixed[2] - 0.8) < 0.003,
      "Red mixer spilled into blue pixels")
    precondition(
      grayMixed.allSatisfy { abs($0 - 0.18) < 0.001 },
      "Color mixer shifted neutral pixels")
    bands[0] = ColorMix(hue: 0, saturation: 0, luminance: 1)
    let brighterRed = channels(ColorMixer.apply(to: redPatch, adjustments: bands))
    let unchangedBlue = channels(ColorMixer.apply(to: bluePatch, adjustments: bands))
    precondition(
      brighterRed[0] > redMixed[0] + 0.2,
      "Red mixer luminance did not raise the selected color")
    precondition(
      abs(unchangedBlue[2] - 0.8) < 0.003,
      "Red mixer luminance spilled into blue pixels")
    bands[0] = ColorMix()
    bands[5].hue = 30
    let shiftedBlue = channels(ColorMixer.apply(to: bluePatch, adjustments: bands))
    precondition(
      abs(shiftedBlue[0] - 0.08) > 0.01 || abs(shiftedBlue[1] - 0.2) > 0.01,
      "Blue mixer hue did not affect blue pixels")
    print("Metal film rendering checks passed")
  }
}

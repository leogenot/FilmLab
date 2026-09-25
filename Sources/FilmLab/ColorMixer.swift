import CoreImage

struct ColorMix: Codable, Equatable {
  var hue = 0.0
  var saturation = 0.0
  var luminance = 0.0
}

/// Eight soft hue bands whose masks all come from the original graded pixel.
enum ColorMixer {
  static let names = ["Red", "Orange", "Yellow", "Green", "Aqua", "Blue", "Purple", "Magenta"]
  private static let legacyKernel = FilmKernels.kernel("colorMixerBand")
  private static let luminancePreservingKernel = FilmKernels.kernel("colorMixerBandV2")

  static func apply(to image: CIImage, adjustments: [ColorMix], version: Int = 2) -> CIImage {
    guard adjustments.count == 8,
      let kernel = version < 2 ? legacyKernel : luminancePreservingKernel
    else { return image }
    let centers = [0.0, 30.0, 60.0, 120.0, 180.0, 240.0, 285.0, 330.0]
    var result = image
    for (index, adjustment) in adjustments.enumerated() {
      guard
        abs(adjustment.hue) > 0.001 || abs(adjustment.saturation) > 0.001
          || abs(adjustment.luminance) > 0.001
      else { continue }
      result =
        kernel.apply(
          extent: image.extent,
          arguments: [
            result, image, centers[index], adjustment.hue, adjustment.saturation,
            adjustment.luminance,
          ]) ?? result
    }
    return result
  }
}

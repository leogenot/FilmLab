import AppKit
import CoreImage

/// Tonal color timing applied after the provisional stock response.
enum ColorGrade {
  private static let kernel = FilmKernels.kernel("grade")

  private static func tint(_ hue: Double) -> CIVector {
    let color = NSColor(
      calibratedHue: CGFloat(hue / 360), saturation: 1,
      brightness: 1, alpha: 1
    ).usingColorSpace(.deviceRGB)!
    let y =
      0.2126 * color.redComponent + 0.7152 * color.greenComponent
      + 0.0722 * color.blueComponent
    return CIVector(
      x: color.redComponent - y,
      y: color.greenComponent - y,
      z: color.blueComponent - y, w: 0)
  }

  static func apply(
    to image: CIImage,
    shadowHue: Double, shadowStrength: Double,
    midHue: Double, midStrength: Double,
    highlightHue: Double, highlightStrength: Double
  ) -> CIImage {
    guard shadowStrength > 0 || midStrength > 0 || highlightStrength > 0,
      let kernel
    else { return image }
    return kernel.apply(
      extent: image.extent,
      arguments: [
        image, tint(shadowHue), shadowStrength,
        tint(midHue), midStrength,
        tint(highlightHue), highlightStrength,
      ]) ?? image
  }
}

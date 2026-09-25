import AppKit
import CoreImage

/// Tonal color timing applied after the provisional stock response.
enum ColorGrade {
  private static let kernel = FilmKernels.kernel("grade")

  private static func legacyTint(_ hue: Double) -> CIVector {
    let color = NSColor(
      calibratedHue: CGFloat(hue / 360), saturation: 1,
      brightness: 1, alpha: 1
    ).usingColorSpace(.deviceRGB)!
    let luminance =
      0.2126 * color.redComponent + 0.7152 * color.greenComponent
      + 0.0722 * color.blueComponent
    return CIVector(
      x: color.redComponent - luminance,
      y: color.greenComponent - luminance,
      z: color.blueComponent - luminance, w: 0)
  }

  private static func tint(_ hue: Double) -> CIVector {
    guard hue.isFinite else { return CIVector(x: 0, y: 0, z: 0, w: 0) }
    let wrapped = (hue.truncatingRemainder(dividingBy: 360) + 360)
      .truncatingRemainder(dividingBy: 360)
    let sector = wrapped / 60
    let secondary = 1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1)
    let rgb: (Double, Double, Double)
    switch Int(sector) {
    case 0: rgb = (1, secondary, 0)
    case 1: rgb = (secondary, 1, 0)
    case 2: rgb = (0, 1, secondary)
    case 3: rgb = (0, secondary, 1)
    case 4: rgb = (secondary, 0, 1)
    default: rgb = (1, 0, secondary)
    }
    let luminance = 0.2126 * rgb.0 + 0.7152 * rgb.1 + 0.0722 * rgb.2
    return CIVector(
      x: rgb.0 - luminance, y: rgb.1 - luminance,
      z: rgb.2 - luminance, w: 0)
  }

  static func apply(
    to image: CIImage,
    shadowHue: Double, shadowStrength: Double,
    midHue: Double, midStrength: Double,
    highlightHue: Double, highlightStrength: Double,
    timingVersion: Int = 2
  ) -> CIImage {
    guard shadowStrength > 0 || midStrength > 0 || highlightStrength > 0,
      let kernel
    else { return image }
    let vector = timingVersion < 2 ? legacyTint : tint
    return kernel.apply(
      extent: image.extent,
      arguments: [
        image, vector(shadowHue), shadowStrength,
        vector(midHue), midStrength,
        vector(highlightHue), highlightStrength,
      ]) ?? image
  }
}

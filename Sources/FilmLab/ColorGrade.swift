import AppKit
import CoreImage

/// Tonal color timing applied after the provisional stock response.
enum ColorGrade {
  private static let kernel = CIColorKernel(
    source: """
          kernel vec4 grade(__sample pixel,
                            vec4 shadowColor, float shadowStrength,
                            vec4 midColor, float midStrength,
                            vec4 highlightColor, float highlightStrength) {
              float luma = dot(pixel.rgb, vec3(0.2126, 0.7152, 0.0722));
              float shadowWeight = 1.0 - smoothstep(0.06, 0.42, luma);
              float highlightWeight = smoothstep(0.38, 0.88, luma);
              float midWeight = smoothstep(0.06, 0.38, luma)
                              * (1.0 - smoothstep(0.48, 0.88, luma));
              vec3 shift = shadowColor.rgb * shadowStrength * shadowWeight
                         + midColor.rgb * midStrength * midWeight
                         + highlightColor.rgb * highlightStrength * highlightWeight;
              float density = clamp(luma + 0.18, 0.18, 1.0);
              return vec4(max(pixel.rgb + shift * density * 0.18, vec3(0.0)), pixel.a);
          }
      """)

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

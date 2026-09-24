import CoreImage

/// Smooth hue-based adjustments within the existing high-precision image graph.
enum SelectiveColor {
  private static let kernel = CIColorKernel(
    source: """
          kernel vec4 selectiveColor(__sample pixel, float targetHue,
                                     float range, float shift, float saturation) {
              vec3 rgb = max(pixel.rgb, vec3(0.0));
              float maximum = max(max(rgb.r, rgb.g), rgb.b);
              float minimum = min(min(rgb.r, rgb.g), rgb.b);
              float chroma = maximum - minimum;
              if (chroma < 0.000001) return pixel;

              float hue;
              if (maximum == rgb.r) hue = (rgb.g - rgb.b) / chroma;
              else if (maximum == rgb.g) hue = (rgb.b - rgb.r) / chroma + 2.0;
              else hue = (rgb.r - rgb.g) / chroma + 4.0;
              hue = fract(hue / 6.0 + 1.0);
              float distance = abs(hue - targetHue / 360.0);
              distance = min(distance, 1.0 - distance) * 360.0;
              float mask = 1.0 - smoothstep(range * 0.55, range, distance);
              mask *= smoothstep(0.02, 0.16, chroma / max(maximum, 0.000001));
              if (mask <= 0.0) return pixel;

              float angle = shift * 0.0174532925199433 * mask;
              float y = dot(rgb, vec3(0.299, 0.587, 0.114));
              float i = dot(rgb, vec3(0.596, -0.275, -0.321));
              float q = dot(rgb, vec3(0.212, -0.523, 0.311));
              float cosine = cos(angle);
              float sine = sin(angle);
              float newI = (i * cosine - q * sine) * max(0.0, 1.0 + saturation * mask);
              float newQ = (i * sine + q * cosine) * max(0.0, 1.0 + saturation * mask);
              vec3 adjusted = vec3(
                  y + 0.956 * newI + 0.621 * newQ,
                  y - 0.272 * newI - 0.647 * newQ,
                  y - 1.106 * newI + 1.703 * newQ
              );
              return vec4(max(adjusted, vec3(0.0)), pixel.a);
          }
      """)

  static func apply(
    to image: CIImage, targetHue: Double, range: Double,
    hueShift: Double, saturation: Double
  ) -> CIImage {
    guard abs(hueShift) > 0.001 || abs(saturation) > 0.001, let kernel else { return image }
    return kernel.apply(
      extent: image.extent,
      arguments: [image, targetHue, range, hueShift, saturation]
    ) ?? image
  }
}

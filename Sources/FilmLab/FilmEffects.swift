import CoreImage
import CoreImage.CIFilterBuiltins

/// Provisional spatial film effects. Values are intentionally conservative until calibrated.
enum FilmEffects {
  private static let grainKernel = CIColorKernel(
    source: """
          kernel vec4 applyGrain(__sample pixel, __sample noise, float amount) {
              float luminance = dot(pixel.rgb, vec3(0.2126, 0.7152, 0.0722));
              float weight = sqrt(clamp(luminance, 0.02, 1.0));
              float grain = (noise.r - 0.5) * amount * 0.14 * weight;
              return vec4(max(pixel.rgb + vec3(grain), vec3(0.0)), pixel.a);
          }
      """)

  private static let highlightKernel = CIColorKernel(
    source: """
          kernel vec4 highlightMask(__sample pixel) {
              float luminance = dot(pixel.rgb, vec3(0.2126, 0.7152, 0.0722));
              float value = smoothstep(0.65, 1.15, luminance);
              return vec4(value, value, value, 1.0);
          }
      """)

  private static let halationKernel = CIColorKernel(
    source: """
          kernel vec4 applyHalation(__sample pixel, __sample mask, __sample blurred, float amount) {
              float spill = max(blurred.r - mask.r, 0.0) * amount * 0.24;
              return vec4(pixel.rgb + vec3(spill, spill * 0.30, spill * 0.12), pixel.a);
          }
      """)

  static func apply(to image: CIImage, grain: Double, halation: Double) -> CIImage {
    var result = image
    if halation > 0,
      let highlightKernel,
      let halationKernel,
      let mask = highlightKernel.apply(extent: image.extent, arguments: [image])
    {
      let blurred = mask.applyingFilter(
        "CIGaussianBlur",
        parameters: [
          kCIInputRadiusKey: 18.0
        ]
      ).cropped(to: image.extent)
      result =
        halationKernel.apply(
          extent: image.extent,
          arguments: [
            result, mask, blurred, halation,
          ]) ?? result
    }
    if grain > 0,
      let grainKernel,
      let noise = CIFilter.randomGenerator().outputImage?.cropped(to: image.extent)
    {
      result =
        grainKernel.apply(
          extent: image.extent,
          arguments: [
            result, noise, grain,
          ]) ?? result
    }
    return result
  }
}

import CoreImage
import CoreImage.CIFilterBuiltins

/// Provisional spatial film effects. Values are intentionally conservative until calibrated.
enum FilmEffects {
  private static let grainKernel = FilmKernels.kernel("applyGrain")

  private static let highlightKernel = FilmKernels.kernel("highlightMask")

  private static let halationKernel = FilmKernels.kernel("applyHalation")

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

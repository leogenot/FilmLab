import CoreImage
import CoreImage.CIFilterBuiltins

/// Provisional spatial film effects. Values are intentionally conservative until calibrated.
enum FilmEffects {
  private static let grainKernel = FilmKernels.kernel("applyGrain")

  private static let highlightKernel = FilmKernels.kernel("highlightMask")

  private static let halationKernel = FilmKernels.kernel("applyHalation")

  private static let acutanceKernel = FilmKernels.kernel("applyAcutance")

  static func apply(
    to image: CIImage, grain: Double, grainSize: Double = 1,
    halation: Double, acutance: Double = 0
  )
    -> CIImage
  {
    var result = image
    if acutance > 0, let acutanceKernel {
      let blurred = result.applyingFilter(
        "CIGaussianBlur", parameters: [kCIInputRadiusKey: 1.5]
      ).cropped(to: image.extent)
      result =
        acutanceKernel.apply(
          extent: image.extent, arguments: [result, blurred, acutance]
        ) ?? result
    }
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
    if grain > 0, let grainKernel {
      result =
        grainKernel.apply(
          extent: image.extent,
          arguments: [
            result, grain, grainSize,
          ]) ?? result
    }
    return result
  }
}

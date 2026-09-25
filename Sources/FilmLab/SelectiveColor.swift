import CoreImage

/// Smooth hue-based adjustments within the existing high-precision image graph.
enum SelectiveColor {
  private static let legacyKernel = FilmKernels.kernel("selectiveColor")
  private static let luminancePreservingKernel = FilmKernels.kernel("preservingSelectiveColor")

  static func apply(
    to image: CIImage, targetHue: Double, range: Double,
    hueShift: Double, saturation: Double, version: Int = 2
  ) -> CIImage {
    guard abs(hueShift) > 0.001 || abs(saturation) > 0.001,
      let kernel = version < 2 ? legacyKernel : luminancePreservingKernel
    else { return image }
    return kernel.apply(
      extent: image.extent,
      arguments: [image, targetHue, range, hueShift, saturation]
    ) ?? image
  }
}

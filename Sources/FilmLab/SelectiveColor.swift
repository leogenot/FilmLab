import CoreImage

/// Smooth hue-based adjustments within the existing high-precision image graph.
enum SelectiveColor {
  private static let kernel = FilmKernels.kernel("selectiveColor")

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

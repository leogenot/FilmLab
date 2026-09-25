import CoreImage

/// Output-only chroma compression for sRGB preview and export.
enum OutputGamutMap {
  private static let kernel = FilmKernels.kernel("compressSRGBGamut")

  static func apply(to image: CIImage) -> CIImage? {
    kernel?.apply(extent: image.extent, arguments: [image])
  }
}

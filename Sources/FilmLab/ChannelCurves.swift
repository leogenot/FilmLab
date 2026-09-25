import CoreImage

struct ChannelCurve: Codable, Equatable {
  var shadow = 0.0
  var midtone = 0.0
  var highlight = 0.0

  var isNeutral: Bool {
    abs(shadow) < 0.000001 && abs(midtone) < 0.000001 && abs(highlight) < 0.000001
  }
}

enum ChannelCurves {
  static let names = ["Red", "Green", "Blue"]
  private static let kernel = FilmKernels.kernel("channelToneCurves")

  static func apply(to image: CIImage, curves: [ChannelCurve]) -> CIImage? {
    guard curves.count == 3 else { return nil }
    guard curves.contains(where: { !$0.isNeutral }) else { return image }
    guard let kernel else { return nil }
    let shadows = CIVector(
      x: curves[0].shadow, y: curves[1].shadow, z: curves[2].shadow, w: 0)
    let midtones = CIVector(
      x: curves[0].midtone, y: curves[1].midtone, z: curves[2].midtone, w: 0)
    let highlights = CIVector(
      x: curves[0].highlight, y: curves[1].highlight, z: curves[2].highlight, w: 0)
    return kernel.apply(
      extent: image.extent,
      arguments: [image, shadows, midtones, highlights])
  }
}

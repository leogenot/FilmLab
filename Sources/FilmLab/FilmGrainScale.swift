import Foundation

enum FilmGrainScale {
  // A creative reference: Grain Size 1 at 7008 pixels along a 36 mm frame
  // produces the existing 2.5-pixel correlation lattice (about 13 microns).
  static let referenceLongEdgePixels = 7008.0

  static func frameLongEdgeMM(_ index: Int) -> Double {
    switch index {
    case 1: 56  // approximate 120 6×6 image aperture
    case 2: 70  // approximate 120 6×7 image aperture
    default: 36  // 135 full frame
    }
  }

  static func sizeInSourcePixels(
    grainSize: Double, sourceLongEdgePixels: Double, frameIndex: Int,
    spatialVersion: Int, thumbnailSpatialScale: Double
  ) -> Double {
    guard spatialVersion >= 2 else { return grainSize * thumbnailSpatialScale }
    return grainSize * max(sourceLongEdgePixels, 1) / referenceLongEdgePixels
      * 36 / frameLongEdgeMM(frameIndex)
  }
}

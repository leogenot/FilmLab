import Foundation
import XCTest

@testable import FilmLab

final class GrainVersionTests: XCTestCase {
  func testDensityGrainPreservesSavedGradesAndCopiesAsTextureEdit() throws {
    let legacy = try JSONDecoder().decode(PhotoEdits.self, from: Data("{}".utf8))
    XCTAssertEqual(legacy.grainVersion, 1)
    XCTAssertEqual(legacy.grainSpatialVersion, 1)
    XCTAssertEqual(legacy.grainFrameIndex, 0)
    XCTAssertEqual(PhotoEdits().grainVersion, 2)
    XCTAssertEqual(PhotoEdits().grainSpatialVersion, 2)
    XCTAssertEqual(legacy.resetting(.texture, isRAW: false).grainVersion, 2)
    XCTAssertEqual(legacy.resetting(.texture, isRAW: false).grainSpatialVersion, 2)

    let destination = PhotoEdits.defaults(forRAW: false)
    let transferred = PhotoEdits.transferring(legacy, panel: .texture, onto: destination)
    XCTAssertEqual(transferred.grainVersion, 1)
    XCTAssertEqual(transferred.grainSpatialVersion, 1)
    let saved = try JSONDecoder().decode(
      PhotoEdits.self, from: JSONEncoder().encode(PhotoEdits()))
    XCTAssertEqual(saved.grainVersion, 2)
    XCTAssertEqual(saved.grainSpatialVersion, 2)
  }

  func testFrameScaleTracksPixelDimensionsAndFilmFormat() {
    let reference = FilmGrainScale.sizeInSourcePixels(
      grainSize: 1, sourceLongEdgePixels: 7008, frameIndex: 0,
      spatialVersion: 2, thumbnailSpatialScale: 1)
    let halfResolution = FilmGrainScale.sizeInSourcePixels(
      grainSize: 1, sourceLongEdgePixels: 3504, frameIndex: 0,
      spatialVersion: 2, thumbnailSpatialScale: 0.5)
    let sixBySix = FilmGrainScale.sizeInSourcePixels(
      grainSize: 1, sourceLongEdgePixels: 7008, frameIndex: 1,
      spatialVersion: 2, thumbnailSpatialScale: 1)
    let legacy = FilmGrainScale.sizeInSourcePixels(
      grainSize: 1, sourceLongEdgePixels: 3504, frameIndex: 1,
      spatialVersion: 1, thumbnailSpatialScale: 0.5)
    XCTAssertEqual(reference, 1, accuracy: 0.00001)
    XCTAssertEqual(halfResolution, 0.5, accuracy: 0.00001)
    XCTAssertEqual(sixBySix, 36.0 / 56.0, accuracy: 0.00001)
    XCTAssertEqual(legacy, 0.5, accuracy: 0.00001)
  }
}

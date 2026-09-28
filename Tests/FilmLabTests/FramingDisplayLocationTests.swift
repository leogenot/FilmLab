import CoreGraphics
import XCTest

@testable import FilmLab

final class FramingDisplayLocationTests: XCTestCase {
  func testSourceAndDisplayLocationsRoundTripThroughFraming() throws {
    let extent = CGRect(x: 0, y: 0, width: 4672, height: 7008)
    let crop = FreeCrop(centerX: 0.48, centerY: 0.52, width: 0.8, height: 0.75)
    for turns in 0..<4 {
      for aspect in [0, 1, 3, 5] {
        for flipped in [false, true] {
          let source = Framing.sourceLocation(
            displayX: 0.48, displayY: 0.53, sourceExtent: extent,
            quarterTurns: turns, straightenDegrees: 7, aspect: aspect,
            offsetX: 0.2, offsetY: -0.3, freeCrop: crop,
            flipHorizontal: flipped, flipVertical: !flipped)
          let unwrapped = try XCTUnwrap(source)
          let display = Framing.displayLocation(
            sourceX: unwrapped.x, sourceY: unwrapped.y, sourceExtent: extent,
            quarterTurns: turns, straightenDegrees: 7, aspect: aspect,
            offsetX: 0.2, offsetY: -0.3, freeCrop: crop,
            flipHorizontal: flipped, flipVertical: !flipped)
          let projected = try XCTUnwrap(display)
          XCTAssertEqual(projected.x, 0.48, accuracy: 0.001)
          XCTAssertEqual(projected.y, 0.53, accuracy: 0.001)
        }
      }
    }
  }

  func testDraggingFixedRatioCropMovesOnlyTheCroppedAxis() {
    let landscape = CGRect(x: 0, y: 0, width: 6000, height: 4000)
    let square = Framing.fixedCropOffsets(
      aspect: 1, sourceExtent: landscape, quarterTurns: 0,
      dragX: 0.1, dragY: 0.1, originalX: 0, originalY: 0)
    XCTAssertEqual(square.x, -0.4, accuracy: 0.0001)
    XCTAssertEqual(square.y, 0, accuracy: 0.0001)

    let wide = Framing.fixedCropOffsets(
      aspect: 4, sourceExtent: landscape, quarterTurns: 0,
      dragX: 0.1, dragY: 0.1, originalX: 0, originalY: 0)
    XCTAssertEqual(wide.x, 0, accuracy: 0.0001)
    XCTAssertGreaterThan(wide.y, 0)

    let rotated = Framing.fixedCropOffsets(
      aspect: 1, sourceExtent: landscape, quarterTurns: 1,
      dragX: 0.1, dragY: 0.1, originalX: 0, originalY: 0)
    XCTAssertEqual(rotated.x, 0, accuracy: 0.0001)
    XCTAssertGreaterThan(rotated.y, 0)
  }
}

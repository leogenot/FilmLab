import XCTest

@testable import FilmLab

final class InputExposureRangeTests: XCTestCase {
  func testPercentilesTrackLinearExposureStops() throws {
    let lights: [Float] = [-2.0, -1.0, 0.0, 1.0, 2.0].map { Float(0.18 * exp2($0)) }
    let pixels = lights.flatMap { [$0, $0, $0, Float(1)] }
    let range = try XCTUnwrap(InputExposureRange.make(from: pixels, width: 5, height: 1))
    XCTAssertEqual(range.lowEV, -1.96, accuracy: 0.001)
    XCTAssertEqual(range.medianEV, 0, accuracy: 0.001)
    XCTAssertEqual(range.highEV, 1.96, accuracy: 0.001)
  }

  func testTransparentPixelsDoNotPullExposureDown() throws {
    let pixels: [Float] = [0, 0, 0, 0, 0.18, 0.18, 0.18, 1]
    let range = try XCTUnwrap(InputExposureRange.make(from: pixels, width: 2, height: 1))
    XCTAssertEqual(range.lowEV, 0, accuracy: 0.001)
    XCTAssertEqual(range.highEV, 0, accuracy: 0.001)
  }
}

import XCTest

@testable import FilmLab

final class HuePickerTests: XCTestCase {
  func testHueMatchesMaskColorWheel() {
    XCTAssertEqual(LinearRGB(red: 1, green: 0, blue: 0).hueDegrees!, 0, accuracy: 0.001)
    XCTAssertEqual(LinearRGB(red: 0, green: 1, blue: 0).hueDegrees!, 120, accuracy: 0.001)
    XCTAssertEqual(LinearRGB(red: 0, green: 0, blue: 1).hueDegrees!, 240, accuracy: 0.001)
    XCTAssertEqual(LinearRGB(red: 1, green: 0, blue: 0.5).hueDegrees!, 330, accuracy: 0.001)
  }

  func testHueRejectsNeutralAndDarkPixels() {
    XCTAssertNil(LinearRGB(red: 0.5, green: 0.5, blue: 0.5).hueDegrees)
    XCTAssertNil(LinearRGB(red: 0.001, green: 0, blue: 0).hueDegrees)
  }

  func testBrightnessMatchesLocalMaskStops() {
    XCTAssertEqual(
      LinearRGB(red: 0.18, green: 0.18, blue: 0.18).stopsFromMiddleGray, 0,
      accuracy: 0.0001)
    XCTAssertEqual(
      LinearRGB(red: 0.36, green: 0.36, blue: 0.36).stopsFromMiddleGray, 1,
      accuracy: 0.0001)
    XCTAssertEqual(
      LinearRGB(red: 0.09, green: 0.09, blue: 0.09).stopsFromMiddleGray, -1,
      accuracy: 0.0001)
    XCTAssertEqual(
      LinearRGB(red: 0, green: 0, blue: 0).stopsFromMiddleGray,
      log2(0.000001 / 0.18), accuracy: 0.0001)
  }

  func testPatchMedianIgnoresIsolatedBrightnessOutlier() {
    var pixels = [LinearRGB](repeating: LinearRGB(red: 0.18, green: 0.18, blue: 0.18), count: 49)
    pixels[24] = LinearRGB(red: 1, green: 1, blue: 1)
    let sample = LocalRangeSample.summarize(pixels, centerIndex: 24)
    XCTAssertEqual(sample!.toneStops, 0, accuracy: 0.0001)
    XCTAssertNil(sample!.hueDegrees)
  }

  func testPatchHueStaysWithClickedColorAtEdge() {
    var pixels = [LinearRGB](repeating: LinearRGB(red: 0, green: 0, blue: 1), count: 49)
    pixels[24] = LinearRGB(red: 1, green: 0, blue: 0)
    let sample = LocalRangeSample.summarize(pixels, centerIndex: 24)
    XCTAssertEqual(sample!.hueDegrees!, 0, accuracy: 0.0001)
  }

  func testPatchHueAveragesAcrossZeroDegrees() {
    let pixels = [
      LinearRGB(red: 1, green: 0, blue: 0.08),
      LinearRGB(red: 1, green: 0.08, blue: 0),
      LinearRGB(red: 1, green: 0, blue: 0),
    ]
    let sample = LocalRangeSample.summarize(pixels, centerIndex: 2)
    XCTAssertEqual(sample!.hueDegrees!, 0, accuracy: 0.0001)
  }
}

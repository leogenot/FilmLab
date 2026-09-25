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
}

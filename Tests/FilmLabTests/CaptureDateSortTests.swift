import ImageIO
import XCTest

@testable import FilmLab

final class CaptureDateSortTests: XCTestCase {
  func testNewestCaptureDateKeepsUndatedPhotosLastAndTiesInImportOrder() {
    let earliest = Date(timeIntervalSince1970: 1)
    let latest = Date(timeIntervalSince1970: 2)
    XCTAssertEqual(
      CaptureDateSort.newestFirst(
        ["undated-a", "early", "latest-a", "undated-b", "latest-b"],
        dates: ["early": earliest, "latest-a": latest, "latest-b": latest]),
      ["latest-a", "latest-b", "early", "undated-a", "undated-b"])
  }

  func testEXIFOriginalTimeAndOffsetTakePrecedenceOverTIFF() throws {
    let original = "2025:03:09 15:13:37"
    let date = try XCTUnwrap(
      CaptureDateSort.captureDate(in: [
        kCGImagePropertyExifDictionary as String: [
          kCGImagePropertyExifDateTimeOriginal as String: original,
          kCGImagePropertyExifOffsetTimeOriginal as String: "+01:00",
        ],
        kCGImagePropertyTIFFDictionary as String: [
          kCGImagePropertyTIFFDateTime as String: "2000:01:01 00:00:00"
        ],
      ]))
    let calendar = Calendar(identifier: .gregorian)
    let utc = calendar.dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: date)
    XCTAssertEqual(utc.year, 2025)
    XCTAssertEqual(utc.month, 3)
    XCTAssertEqual(utc.day, 9)
    XCTAssertEqual(utc.hour, 14)
    XCTAssertEqual(utc.minute, 13)
  }

  func testReadsDisposableRAWAndJPEGCaptureDates() throws {
    guard let raw = ProcessInfo.processInfo.environment["FILMLAB_TEST_RAW"],
      let jpeg = ProcessInfo.processInfo.environment["FILMLAB_TEST_JPEG"]
    else { throw XCTSkip("Set FILMLAB_TEST_RAW and FILMLAB_TEST_JPEG") }
    let dates = CaptureDateSort.dates(for: [raw, jpeg])
    XCTAssertNotNil(dates[raw])
    XCTAssertNotNil(dates[jpeg])
    XCTAssertEqual(dates[raw], dates[jpeg])
  }
}

import Foundation
import XCTest

@testable import FilmLab

final class MultigradePaperTests: XCTestCase {
  func testPaperStudyIsOptInAndCopiesWithFilmSettings() throws {
    let legacy = try JSONDecoder().decode(PhotoEdits.self, from: Data("{}".utf8))
    XCTAssertFalse(legacy.multigradePaper)
    XCTAssertEqual(legacy.multigradeGradeIndex, 3)

    var source = PhotoEdits()
    source.multigradePaper = true
    source.multigradeGradeIndex = 6
    let restored = try JSONDecoder().decode(
      PhotoEdits.self, from: JSONEncoder().encode(source))
    XCTAssertTrue(restored.multigradePaper)
    XCTAssertEqual(restored.multigradeGradeIndex, 6)

    let destination = PhotoEdits.defaults(forRAW: false)
    let copied = PhotoEdits.transferring(source, panel: .film, onto: destination)
    XCTAssertTrue(copied.multigradePaper)
    XCTAssertEqual(copied.multigradeGradeIndex, 6)
    let reset = copied.resetting(.film, isRAW: false)
    XCTAssertFalse(reset.multigradePaper)
    XCTAssertEqual(reset.multigradeGradeIndex, 3)
  }
}

import XCTest

@testable import FilmLab

final class ColorMixerVersionTests: XCTestCase {
  func testLegacyGradeKeepsOriginalMixerUntilUpgrade() throws {
    let legacy = try JSONDecoder().decode(PhotoEdits.self, from: Data("{}".utf8))
    XCTAssertEqual(legacy.mixerVersion, 1)
    XCTAssertEqual(PhotoEdits().mixerVersion, 2)

    let destination = PhotoEdits.defaults(forRAW: true)
    let transferred = PhotoEdits.transferring(legacy, panel: .color, onto: destination)
    XCTAssertEqual(transferred.mixerVersion, 1)
    XCTAssertEqual(transferred.resetting(.color, isRAW: true).mixerVersion, 1)
    XCTAssertEqual(legacy.resetting(.color, isRAW: false).mixerVersion, 1)
  }

  func testNewGradeRoundTripRetainsMixerVersion() throws {
    let saved = try JSONEncoder().encode(PhotoEdits.defaults(forRAW: false))
    let loaded = try JSONDecoder().decode(PhotoEdits.self, from: saved)
    XCTAssertEqual(loaded.mixerVersion, 2)
  }
}

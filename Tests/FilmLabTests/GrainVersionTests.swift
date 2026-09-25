import Foundation
import XCTest

@testable import FilmLab

final class GrainVersionTests: XCTestCase {
  func testDensityGrainPreservesSavedGradesAndCopiesAsTextureEdit() throws {
    let legacy = try JSONDecoder().decode(PhotoEdits.self, from: Data("{}".utf8))
    XCTAssertEqual(legacy.grainVersion, 1)
    XCTAssertEqual(PhotoEdits().grainVersion, 2)
    XCTAssertEqual(legacy.resetting(.texture, isRAW: false).grainVersion, 2)

    let destination = PhotoEdits.defaults(forRAW: false)
    let transferred = PhotoEdits.transferring(legacy, panel: .texture, onto: destination)
    XCTAssertEqual(transferred.grainVersion, 1)
    let saved = try JSONDecoder().decode(
      PhotoEdits.self, from: JSONEncoder().encode(PhotoEdits()))
    XCTAssertEqual(saved.grainVersion, 2)
  }
}

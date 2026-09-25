import XCTest

@testable import FilmLab

final class ChannelCurvesTests: XCTestCase {
  func testLegacyGradesStartWithNeutralChannelCurves() throws {
    let legacy = try JSONDecoder().decode(PhotoEdits.self, from: Data("{}".utf8))
    XCTAssertEqual(legacy.channelCurves, Array(repeating: ChannelCurve(), count: 3))
  }

  func testColorWorkspaceTransfersAndResetsChannelCurves() throws {
    var copied = PhotoEdits()
    copied.channelCurves[0].midtone = 0.12
    copied.channelCurves[2].shadow = -0.08
    let destination = PhotoEdits.defaults(forRAW: true)
    let transferred = PhotoEdits.transferring(copied, panel: .color, onto: destination)
    XCTAssertEqual(transferred.channelCurves, copied.channelCurves)
    XCTAssertTrue(transferred.resetting(.color, isRAW: true).channelCurves.allSatisfy(\.isNeutral))

    let saved = try JSONEncoder().encode(transferred)
    let reloaded = try JSONDecoder().decode(PhotoEdits.self, from: saved)
    XCTAssertEqual(reloaded.channelCurves, copied.channelCurves)
  }
}

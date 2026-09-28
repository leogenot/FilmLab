import Foundation
import XCTest

@testable import FilmLab

final class PrinterBalanceTests: XCTestCase {
  func testPrinterBalanceDefaultsAndFilmPanelTransfer() throws {
    let legacy = try JSONDecoder().decode(PhotoEdits.self, from: Data("{}".utf8))
    XCTAssertEqual(legacy.printerMagentaStops, 0)
    XCTAssertEqual(legacy.printerYellowStops, 0)

    var source = PhotoEdits()
    source.opticalPremierPrint = true
    source.printerMagentaStops = 0.7
    source.printerYellowStops = -0.4
    let encoded = try JSONEncoder().encode(source)
    let restored = try JSONDecoder().decode(PhotoEdits.self, from: encoded)
    XCTAssertEqual(restored.printerMagentaStops, 0.7)
    XCTAssertEqual(restored.printerYellowStops, -0.4)

    let destination = PhotoEdits.defaults(forRAW: false)
    let transferred = PhotoEdits.transferring(source, panel: .film, onto: destination)
    XCTAssertEqual(transferred.printerMagentaStops, 0.7)
    XCTAssertEqual(transferred.printerYellowStops, -0.4)
    let reset = transferred.resetting(.film, isRAW: false)
    XCTAssertEqual(reset.printerMagentaStops, 0)
    XCTAssertEqual(reset.printerYellowStops, 0)
  }
}

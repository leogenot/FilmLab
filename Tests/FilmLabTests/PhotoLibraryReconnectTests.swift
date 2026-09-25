import Foundation
import XCTest

@testable import FilmLab

final class PhotoLibraryReconnectTests: XCTestCase {
  func testReconnectsMovedOriginalsAcrossCatalogsAndTransfersEdits() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-reconnect-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let editsDirectory = root.appendingPathComponent("Edits")
    let first = root.appendingPathComponent("first.jpg")
    let second = root.appendingPathComponent("second.jpg")
    let movedFirst = root.appendingPathComponent("moved-first.jpg")
    let movedSecond = root.appendingPathComponent("moved-second.jpg")
    let untracked = root.appendingPathComponent("untracked.jpg")
    try Data("first".utf8).write(to: first)
    try Data("second".utf8).write(to: second)

    var library = PhotoLibrary.empty()
    let catalogID = library.selectedCatalogID
    XCTAssertEqual(library.importPhotos([first, second]), 2)
    library.catalogs[0].photoPaths.append(untracked.path)
    library.toggleFavorite(first.path)
    library.createCatalog(named: "Other")
    XCTAssertEqual(library.importPhotos([first]), 1)
    library.selectedCatalogID = catalogID
    XCTAssertNotNil(library.photoBookmarks[first.path])
    XCTAssertNotNil(library.photoBookmarks[second.path])

    var edits = PhotoEdits()
    edits.shotExposure = 1.25
    let oldRecord = EditRecordLocator.locate(sourceURL: first, directory: editsDirectory)
    try SavedEditStore.save(edits, to: oldRecord.pathURL)
    try FileManager.default.moveItem(at: first, to: movedFirst)
    try FileManager.default.moveItem(at: second, to: movedSecond)

    let result = await PhotoLibraryReconnect.run(
      library, in: catalogID, editsDirectory: editsDirectory)
    XCTAssertFalse(result.cancelled)
    XCTAssertEqual(result.relinked.count, 2)
    XCTAssertEqual(result.unresolved, 1)
    XCTAssertEqual(result.unavailableEdits, 1)
    XCTAssertTrue(result.failures.isEmpty)
    XCTAssertEqual(library.catalogs[0].photoPaths[0], first.path)
    XCTAssertEqual(
      result.library.selectedCatalog?.photoPaths,
      [movedFirst.path, movedSecond.path, untracked.path])
    XCTAssertEqual(result.library.catalogs[1].photoPaths, [movedFirst.path])
    XCTAssertTrue(result.library.favoritePaths.contains(movedFirst.path))
    XCTAssertFalse(result.library.favoritePaths.contains(first.path))
    let newRecord = EditRecordLocator.locate(sourceURL: movedFirst, directory: editsDirectory)
    let copied = try JSONDecoder().decode(
      PhotoEdits.self, from: Data(contentsOf: newRecord.pathURL))
    XCTAssertEqual(copied.shotExposure, 1.25)
    XCTAssertTrue(FileManager.default.fileExists(atPath: oldRecord.pathURL.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: movedFirst.path))

    let index = root.appendingPathComponent("Library.json")
    let saved = try PhotoLibraryStore.updating(library, at: index) { $0 = result.library }
    XCTAssertEqual(PhotoLibraryStore.load(from: index), saved)
  }
}

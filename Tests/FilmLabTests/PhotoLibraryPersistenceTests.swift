import Foundation
import XCTest

@testable import FilmLab

final class PhotoLibraryPersistenceTests: XCTestCase {
  func testSuccessfulUpdatePersistsBeforeReturningNewLibrary() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-library-update-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let index = directory.appendingPathComponent("Library.json")
    let original = PhotoLibrary.empty()

    let updated = try PhotoLibraryStore.updating(original, at: index) {
      $0.createCatalog(named: "Portraits")
    }

    XCTAssertEqual(original.catalogs.count, 1)
    XCTAssertEqual(updated.catalogs.count, 2)
    XCTAssertEqual(PhotoLibraryStore.load(from: index), updated)
  }

  func testFailedUpdateLeavesOriginalLibraryUnchanged() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-library-update-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let blocker = directory.appendingPathComponent("blocking-file")
    try Data("file".utf8).write(to: blocker)
    let index = blocker.appendingPathComponent("Library.json")
    let original = PhotoLibrary.empty()

    XCTAssertThrowsError(
      try PhotoLibraryStore.updating(original, at: index) {
        $0.createCatalog(named: "Unsaved")
      })
    XCTAssertEqual(original.catalogs.count, 1)
    XCTAssertFalse(FileManager.default.fileExists(atPath: index.path))
  }
}

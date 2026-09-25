import Foundation
import XCTest

@testable import FilmLab

final class PhotoFolderScannerTests: XCTestCase {
  func testScansNestedPhotosAndSkipsOtherFilesAndHiddenFolders() async throws {
    let folder = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-folder-scan-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: folder) }
    let nested = folder.appendingPathComponent("Nested")
    let hidden = folder.appendingPathComponent(".Hidden")
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: hidden, withIntermediateDirectories: true)
    for path in ["b.jpg", "Nested/a.ARW", "Nested/notes.txt", ".Hidden/secret.jpg"] {
      try Data("test".utf8).write(to: folder.appendingPathComponent(path))
    }

    let found = try await PhotoFolderScanner().scan(folder).map(\.lastPathComponent)
    XCTAssertEqual(Set(found), ["a.ARW", "b.jpg"])
  }

  func testImportsIntoOriginalCatalogAndIgnoresDuplicates() {
    var library = PhotoLibrary.empty()
    let firstCatalog = library.selectedCatalogID
    library.createCatalog(named: "Second")
    let photo = URL(fileURLWithPath: "/tmp/scene.jpg")
    XCTAssertEqual(library.importPhotos([photo, photo], into: firstCatalog), 1)
    XCTAssertEqual(library.catalogs.first?.photoPaths, [photo.path])
    XCTAssertEqual(library.selectedCatalog?.photoPaths, [])
    XCTAssertEqual(library.importPhotos([photo], into: firstCatalog), 0)
  }
}

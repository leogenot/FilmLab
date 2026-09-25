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

  func testTrackedFolderRefreshAddsOnlyNewPhotosToItsCatalog() async throws {
    let folder = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-folder-refresh-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: folder) }
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let first = folder.appendingPathComponent("first.jpg")
    try Data("first".utf8).write(to: first)

    var library = PhotoLibrary.empty()
    let originalCatalog = library.selectedCatalogID
    XCTAssertTrue(library.trackImportedFolder(folder, in: originalCatalog))
    XCTAssertFalse(library.trackImportedFolder(folder, in: originalCatalog))
    let initialPhotos = try await PhotoFolderScanner().scan(folder)
    XCTAssertEqual(library.importPhotos(initialPhotos), 1)

    library.createCatalog(named: "Another catalog")
    let second = folder.appendingPathComponent("second.ARW")
    try Data("second".utf8).write(to: second)
    let refreshedPhotos = try await PhotoFolderScanner().scan(folder)
    XCTAssertEqual(library.importPhotos(refreshedPhotos, into: originalCatalog), 1)
    XCTAssertEqual(library.catalogs[0].photoPaths, [first.path, second.path])
    XCTAssertEqual(library.selectedCatalog?.photoPaths, [])
  }

  func testLegacyCatalogLoadsWithoutTrackedFolders() throws {
    let id = UUID()
    let data = Data(
      "{\"id\":\"\(id.uuidString)\",\"name\":\"Old\",\"photoPaths\":[\"/tmp/a.jpg\"]}".utf8)
    let catalog = try JSONDecoder().decode(PhotoCatalog.self, from: data)
    XCTAssertEqual(catalog.importedFolderPaths, [])
    XCTAssertEqual(catalog.photoPaths, ["/tmp/a.jpg"])
  }
}

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

    XCTAssertTrue(library.untrackImportedFolder(folder.path, in: originalCatalog))
    XCTAssertFalse(library.untrackImportedFolder(folder.path, in: originalCatalog))
    XCTAssertEqual(library.catalogs[0].importedFolderPaths, [])
    XCTAssertEqual(library.catalogs[0].photoPaths, [first.path, second.path])
  }

  func testLegacyCatalogLoadsWithoutTrackedFolders() throws {
    let id = UUID()
    let data = Data(
      "{\"id\":\"\(id.uuidString)\",\"name\":\"Old\",\"photoPaths\":[\"/tmp/a.jpg\"]}".utf8)
    let catalog = try JSONDecoder().decode(PhotoCatalog.self, from: data)
    XCTAssertEqual(catalog.importedFolderPaths, [])
    XCTAssertEqual(catalog.photoPaths, ["/tmp/a.jpg"])
  }

  func testMovedFolderRelinksNestedPhotosAndRefreshLocation() {
    var library = PhotoLibrary.empty()
    let catalogID = library.selectedCatalogID
    let oldFolder = URL(fileURLWithPath: "/tmp/FilmLab-old-session")
    let newFolder = URL(fileURLWithPath: "/tmp/FilmLab-new-session")
    let oldPortrait = oldFolder.appendingPathComponent("Portraits/one.ARW")
    let oldLandscape = oldFolder.appendingPathComponent("Landscapes/two.jpg")
    let unrelated = URL(fileURLWithPath: "/tmp/FilmLab-old-session-extra/three.jpg")
    library.importPhotos([oldPortrait, oldLandscape, unrelated])
    library.trackImportedFolder(oldFolder, in: catalogID)
    library.toggleFavorite(oldPortrait.path)

    let replacement = newFolder.appendingPathComponent("Portraits/one.ARW")
    let candidates = library.movedFolderCandidates(
      from: oldFolder.path, to: newFolder,
      scannedPhotos: [replacement, newFolder.appendingPathComponent("other.jpg")], in: catalogID)
    XCTAssertEqual(candidates.map(\.0), [oldPortrait.path])
    XCTAssertEqual(candidates.map(\.1), [replacement])
    library.relinkPhoto(from: candidates[0].0, to: candidates[0].1)
    XCTAssertTrue(library.relinkImportedFolder(oldFolder.path, to: newFolder, in: catalogID))

    XCTAssertEqual(library.selectedCatalog?.importedFolderPaths, [newFolder.path])
    XCTAssertEqual(
      library.selectedCatalog?.photoPaths,
      [replacement.path, oldLandscape.path, unrelated.path])
    XCTAssertTrue(library.favoritePaths.contains(replacement.path))
    XCTAssertFalse(library.favoritePaths.contains(oldPortrait.path))
  }

  func testMovedSharedFolderRelinksEveryCatalogOnce() {
    var library = PhotoLibrary.empty()
    let firstID = library.selectedCatalogID
    let oldFolder = URL(fileURLWithPath: "/tmp/FilmLab-shared-old")
    let newFolder = URL(fileURLWithPath: "/tmp/FilmLab-shared-new")
    let shared = oldFolder.appendingPathComponent("one.ARW")
    let other = oldFolder.appendingPathComponent("two.jpg")
    let movedShared = newFolder.appendingPathComponent("one.ARW")
    let movedOther = newFolder.appendingPathComponent("two.jpg")
    library.importPhotos([shared])
    library.trackImportedFolder(oldFolder, in: firstID)
    library.createCatalog(named: "Second")
    let secondID = library.selectedCatalogID
    library.importPhotos([shared, other])
    library.trackImportedFolder(oldFolder, in: secondID)
    library.selectedCatalogID = firstID

    let candidates = library.movedFolderCandidates(
      from: oldFolder.path, to: newFolder,
      scannedPhotos: [movedShared, movedOther], in: firstID)
    XCTAssertEqual(Set(candidates.map(\.0)), [shared.path, other.path])
    XCTAssertEqual(candidates.count, 2)
    for (old, replacement) in candidates {
      library.relinkPhoto(from: old, to: replacement)
    }
    XCTAssertTrue(library.relinkImportedFolder(oldFolder.path, to: newFolder, in: firstID))
    XCTAssertEqual(library.catalogs[0].importedFolderPaths, [newFolder.path])
    XCTAssertEqual(library.catalogs[1].importedFolderPaths, [newFolder.path])
    XCTAssertEqual(library.catalogs[0].photoPaths, [movedShared.path])
    XCTAssertEqual(library.catalogs[1].photoPaths, [movedShared.path, movedOther.path])
  }
}

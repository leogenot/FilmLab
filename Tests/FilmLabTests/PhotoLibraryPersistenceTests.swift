import Foundation
import XCTest

@testable import FilmLab

final class PhotoLibraryPersistenceTests: XCTestCase {
  func testBatchOrganizationPreservesSharedReferencesAndOriginals() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-batch-library-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let first = directory.appendingPathComponent("first.jpg")
    let second = directory.appendingPathComponent("second.jpg")
    try Data("first".utf8).write(to: first)
    try Data("second".utf8).write(to: second)
    let index = directory.appendingPathComponent("Library.json")
    var library = PhotoLibrary.empty()
    let originalID = library.selectedCatalogID
    library.importPhotos([first, second])
    library.createCatalog(named: "Keepers")
    let keeperID = library.selectedCatalogID
    library.importPhotos([first], into: keeperID)
    library.selectedCatalogID = originalID
    try PhotoLibraryStore.save(library, to: index)

    library = try PhotoLibraryStore.updating(library, at: index) {
      $0.setFavorites([first.path, second.path, "/missing.jpg"], favorite: true)
      $0.removePhotos([first.path, second.path])
    }
    XCTAssertEqual(library.catalogs[0].photoPaths, [])
    XCTAssertEqual(library.catalogs[1].photoPaths, [first.path])
    XCTAssertEqual(library.favoritePaths, [first.path])
    XCTAssertNotNil(library.photoBookmarks[first.path])
    XCTAssertNil(library.photoBookmarks[second.path])
    XCTAssertTrue(FileManager.default.fileExists(atPath: first.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: second.path))
    XCTAssertEqual(PhotoLibraryStore.load(from: index), library)

    library.setFavorites([first.path], favorite: false)
    XCTAssertTrue(library.favoritePaths.isEmpty)
  }

  func testDamagedLibraryRestoresLastSavedCatalogState() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-library-recovery-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let index = directory.appendingPathComponent("Library.json")
    var original = PhotoLibrary.empty()
    original.createCatalog(named: "Portraits")
    try PhotoLibraryStore.save(original, to: index)
    var newer = original
    newer.createCatalog(named: "Travel")
    try PhotoLibraryStore.save(newer, to: index)
    try Data("not json".utf8).write(to: index, options: .atomic)

    let loaded = PhotoLibraryStore.loadSafely(from: index)
    XCTAssertTrue(loaded.canSave)
    XCTAssertEqual(loaded.value, original)
    XCTAssertEqual(PhotoLibraryStore.load(from: index), original)
    XCTAssertNotNil(loaded.notice)
    XCTAssertEqual(try Data(contentsOf: XCTUnwrap(loaded.backupURL)), Data("not json".utf8))
  }

  func testMissingLibraryRestoresPreviousIndex() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-library-missing-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let index = directory.appendingPathComponent("Library.json")
    let original = PhotoLibrary.empty()
    try PhotoLibraryStore.save(original, to: index)
    var newer = original
    newer.createCatalog(named: "Travel")
    try PhotoLibraryStore.save(newer, to: index)
    try FileManager.default.removeItem(at: index)

    let loaded = PhotoLibraryStore.loadSafely(from: index)
    XCTAssertTrue(loaded.canSave)
    XCTAssertEqual(loaded.value, original)
    XCTAssertEqual(PhotoLibraryStore.load(from: index), original)
  }

  func testStructurallyEmptyLibraryPreservesDamagedIndexBeforeRecovery() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-library-empty-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let index = directory.appendingPathComponent("Library.json")
    let original = PhotoLibrary.empty()
    try PhotoLibraryStore.save(original, to: index)
    var newer = original
    newer.createCatalog(named: "Travel")
    try PhotoLibraryStore.save(newer, to: index)
    var empty = newer
    empty.catalogs = []
    let damagedData = try JSONEncoder().encode(empty)
    try damagedData.write(to: index, options: .atomic)

    let loaded = PhotoLibraryStore.loadSafely(from: index)
    XCTAssertEqual(loaded.value, original)
    XCTAssertTrue(loaded.canSave)
    XCTAssertEqual(try Data(contentsOf: XCTUnwrap(loaded.backupURL)), damagedData)
  }

  func testDamagedLibraryWithoutValidPreviousIndexPausesSaving() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-library-no-backup-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let index = directory.appendingPathComponent("Library.json")
    let damagedData = Data("not json".utf8)
    try damagedData.write(to: index)

    let loaded = PhotoLibraryStore.loadSafely(from: index)
    XCTAssertFalse(loaded.canSave)
    XCTAssertNotNil(loaded.notice)
    XCTAssertEqual(try Data(contentsOf: index), damagedData)
    XCTAssertEqual(try Data(contentsOf: XCTUnwrap(loaded.backupURL)), damagedData)
  }

  func testFailedPreviousIndexWriteDoesNotReplaceLibrary() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-library-backup-blocked-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let index = directory.appendingPathComponent("Library.json")
    let original = PhotoLibrary.empty()
    try PhotoLibraryStore.save(original, to: index)
    let blocker = directory.appendingPathComponent("Library.previous.json")
    try FileManager.default.createDirectory(at: blocker, withIntermediateDirectories: true)
    var newer = original
    newer.createCatalog(named: "Travel")

    XCTAssertThrowsError(try PhotoLibraryStore.save(newer, to: index))
    XCTAssertEqual(PhotoLibraryStore.load(from: index), original)
  }

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

  func testBookmarkReconnectsRenamedOriginalAfterLibraryReload() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-library-bookmark-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let original = directory.appendingPathComponent("original.jpg")
    let renamed = directory.appendingPathComponent("renamed.jpg")
    let index = directory.appendingPathComponent("Library.json")
    try Data("photo".utf8).write(to: original)

    var library = PhotoLibrary.empty()
    XCTAssertEqual(library.importPhotos([original]), 1)
    library.toggleFavorite(original.standardizedFileURL.path)
    XCTAssertNotNil(library.photoBookmarks[original.standardizedFileURL.path])
    try PhotoLibraryStore.save(library, to: index)
    try FileManager.default.moveItem(at: original, to: renamed)

    var reopened = PhotoLibraryStore.load(from: index)
    let resolved = try XCTUnwrap(
      reopened.resolvedMissingPhoto(at: original.standardizedFileURL.path))
    XCTAssertEqual(
      resolved.resolvingSymlinksInPath().path,
      renamed.resolvingSymlinksInPath().path)
    reopened.relinkPhoto(from: original.standardizedFileURL.path, to: resolved)
    XCTAssertEqual(reopened.selectedCatalog?.photoPaths, [resolved.standardizedFileURL.path])
    XCTAssertTrue(reopened.favoritePaths.contains(resolved.standardizedFileURL.path))
    XCTAssertNil(reopened.photoBookmarks[original.standardizedFileURL.path])
    XCTAssertNotNil(reopened.photoBookmarks[resolved.standardizedFileURL.path])
    try PhotoLibraryStore.save(reopened, to: index)
    XCTAssertEqual(PhotoLibraryStore.load(from: index), reopened)
    reopened.removePhoto(resolved.standardizedFileURL.path)
    XCTAssertTrue(reopened.photoBookmarks.isEmpty)
  }

  func testLinkedFolderBookmarkSurvivesReloadAndResolvesMove() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-folder-bookmark-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let original = directory.appendingPathComponent("Original", isDirectory: true)
    let moved = directory.appendingPathComponent("Moved", isDirectory: true)
    try FileManager.default.createDirectory(at: original, withIntermediateDirectories: true)
    let index = directory.appendingPathComponent("Library.json")
    var library = PhotoLibrary.empty()
    XCTAssertTrue(library.trackImportedFolder(original, in: library.selectedCatalogID))
    XCTAssertNotNil(library.folderBookmarks[original.path])
    try PhotoLibraryStore.save(library, to: index)
    try FileManager.default.moveItem(at: original, to: moved)

    var reopened = PhotoLibraryStore.load(from: index)
    let resolved = try XCTUnwrap(reopened.resolvedMissingFolder(at: original.path))
    XCTAssertEqual(resolved.resolvingSymlinksInPath().path, moved.resolvingSymlinksInPath().path)
    XCTAssertTrue(
      reopened.relinkImportedFolder(original.path, to: resolved, in: reopened.selectedCatalogID))
    XCTAssertEqual(reopened.selectedCatalog?.importedFolderPaths, [moved.path])
    XCTAssertNil(reopened.folderBookmarks[original.path])
    XCTAssertNotNil(reopened.folderBookmarks[moved.path])
    try PhotoLibraryStore.save(reopened, to: index)
    XCTAssertEqual(PhotoLibraryStore.load(from: index), reopened)
    XCTAssertTrue(reopened.untrackImportedFolder(moved.path, in: reopened.selectedCatalogID))
    XCTAssertTrue(reopened.folderBookmarks.isEmpty)
  }

  func testLegacyLibraryWithoutFolderBookmarksStillDecodes() throws {
    let library = PhotoLibrary.empty()
    let data = try JSONEncoder().encode(library)
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    object.removeValue(forKey: "folderBookmarks")
    let legacyData = try JSONSerialization.data(withJSONObject: object)
    let decoded = try JSONDecoder().decode(PhotoLibrary.self, from: legacyData)
    XCTAssertEqual(decoded.catalogs, library.catalogs)
    XCTAssertTrue(decoded.folderBookmarks.isEmpty)
  }

  func testReimportBackfillsBookmarkWithoutDuplicatingPhoto() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-library-backfill-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let photo = directory.appendingPathComponent("photo.jpg")
    try Data("photo".utf8).write(to: photo)
    var catalog = PhotoLibrary.empty()
    catalog.catalogs[0].photoPaths = [photo.standardizedFileURL.path]
    let index = directory.appendingPathComponent("Library.json")

    let updated = try PhotoLibraryStore.updating(catalog, at: index) {
      XCTAssertEqual($0.importPhotos([photo]), 0)
    }
    XCTAssertEqual(updated.selectedCatalog?.photoPaths, [photo.standardizedFileURL.path])
    XCTAssertNotNil(updated.photoBookmarks[photo.standardizedFileURL.path])
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

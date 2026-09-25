import CoreImage
import Foundation
import XCTest

@testable import FilmLab

final class BatchPasteCancellationTests: XCTestCase {
  @MainActor func testBatchKeepsItsInitiallyOpenPhotoExcludedAfterNavigation() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-batch-active-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let original = root.appendingPathComponent("original.jpg")
    let next = root.appendingPathComponent("next.jpg")
    try Data("photo".utf8).write(to: original)
    try Data("photo".utf8).write(to: next)
    let editsDirectory = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("FilmLab/Edits")
    let location = EditRecordLocator.locate(sourceURL: original, directory: editsDirectory)
    defer {
      try? FileManager.default.removeItem(at: location.primaryURL)
      try? FileManager.default.removeItem(at: location.pathURL)
    }

    let editor = PhotoEditor()
    editor.sourceURL = original
    editor.shotExposure = 1.25
    editor.copyWorkspace(.film)
    let outcome = await editor.pasteSettings(to: [original.path], workspaceOnly: true) { _, _ in
      editor.sourceURL = next
    }

    XCTAssertEqual(outcome.changedPaths, [])
    XCTAssertTrue(outcome.summary.contains("Skipped 1"), outcome.summary)
    XCTAssertFalse(FileManager.default.fileExists(atPath: location.pathURL.path))
    XCTAssertFalse(FileManager.default.fileExists(atPath: location.primaryURL.path))
  }

  @MainActor func testUnreadableOriginalIsNotGivenNewBatchEdits() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-batch-unreadable-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("source.jpg")
    let damaged = root.appendingPathComponent("damaged.jpg")
    try writeJPEG(to: source)
    try Data("not a photo".utf8).write(to: damaged)
    let location = EditRecordLocator.locate(
      sourceURL: damaged,
      directory: FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("FilmLab/Edits"))
    defer {
      try? FileManager.default.removeItem(at: location.primaryURL)
      try? FileManager.default.removeItem(at: location.pathURL)
    }

    let editor = PhotoEditor()
    editor.sourceURL = source
    editor.shotExposure = 1.25
    editor.copyWorkspace(.film)
    let outcome = await editor.pasteSettings(to: [damaged.path], workspaceOnly: true)
    XCTAssertTrue(outcome.changedPaths.isEmpty)
    XCTAssertTrue(outcome.summary.contains("damaged.jpg (unreadable original)"), outcome.summary)
    XCTAssertFalse(FileManager.default.fileExists(atPath: location.primaryURL.path))
    XCTAssertFalse(FileManager.default.fileExists(atPath: location.pathURL.path))
  }

  @MainActor func testSavedLookAppliesToBatchWithoutReplacingInputOrUndo() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-batch-look-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let target = root.appendingPathComponent("target.jpg")
    try writeJPEG(to: target)
    let lookURL = root.appendingPathComponent("look.json")
    var look = PhotoEdits()
    look.stockIndex = 2
    look.shotExposure = 1.25
    look.inputTone = 1.4
    look.rawTemperature = 3_200
    look.grainSeed = 999
    try LookFile(settings: look).write(to: lookURL)
    let loadedLook: PhotoEdits = try LookFile.read(from: lookURL)

    let support = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("FilmLab", isDirectory: true)
    let history = support.appendingPathComponent("BatchHistory.json")
    let previousHistory = try? Data(contentsOf: history)
    defer {
      if let previousHistory {
        try? previousHistory.write(to: history, options: .atomic)
      } else {
        try? FileManager.default.removeItem(at: history)
      }
    }
    let editsDirectory = support.appendingPathComponent("Edits", isDirectory: true)
    let backupsDirectory = editsDirectory.appendingPathComponent(
      "BatchBackups", isDirectory: true)
    let previousBackups = Set(
      (try? FileManager.default.contentsOfDirectory(
        at: backupsDirectory, includingPropertiesForKeys: nil)) ?? [])
    defer {
      let current = Set(
        (try? FileManager.default.contentsOfDirectory(
          at: backupsDirectory, includingPropertiesForKeys: nil)) ?? [])
      for url in current.subtracting(previousBackups) {
        try? FileManager.default.removeItem(at: url)
      }
    }
    let location = EditRecordLocator.locate(sourceURL: target, directory: editsDirectory)
    defer {
      try? FileManager.default.removeItem(at: location.pathURL)
      if location.primaryURL != location.pathURL {
        try? FileManager.default.removeItem(at: location.primaryURL)
      }
    }
    var before = PhotoEdits.defaults(forRAW: false, grainSeed: 123)
    before.inputTone = 0.8
    try SavedEditStore.save(before, to: location.pathURL)
    if location.primaryURL != location.pathURL {
      try SavedEditStore.save(before, to: location.primaryURL)
    }

    let editor = PhotoEditor()
    let outcome = await editor.pasteSettings(to: [target.path], look: loadedLook)
    XCTAssertEqual(outcome.changedPaths, [target.path])
    let applied = try JSONDecoder().decode(
      PhotoEdits.self, from: Data(contentsOf: location.primaryURL))
    XCTAssertEqual(applied.stockIndex, 2)
    XCTAssertEqual(applied.shotExposure, 1.25)
    XCTAssertEqual(applied.inputTone, 0.8)
    XCTAssertNil(applied.rawTemperature)
    XCTAssertEqual(applied.grainSeed, 123)

    XCTAssertTrue(editor.undoLastBatch().contains("Restored settings on 1 photo"))
    let restored = try JSONDecoder().decode(
      PhotoEdits.self, from: Data(contentsOf: location.primaryURL))
    XCTAssertEqual(restored, before)
  }

  private struct PendingChange: Encodable {
    let path: String
    let location: EditRecordLocation
    let before: PhotoEdits
    let after: PhotoEdits
  }

  private struct PendingHistory: Encodable {
    let version = 1
    let changes: [PendingChange]
  }

  @MainActor func testUndoRecoversAnIntentInterruptedBeforeOrAfterEditWrite() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-batch-intent-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let photo = root.appendingPathComponent("target.jpg")
    try Data("photo".utf8).write(to: photo)
    let support = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("FilmLab", isDirectory: true)
    let history = support.appendingPathComponent("BatchHistory.json")
    let originalHistory = try? Data(contentsOf: history)
    defer {
      if let originalHistory {
        try? originalHistory.write(to: history, options: .atomic)
      } else {
        try? FileManager.default.removeItem(at: history)
      }
    }
    let location = EditRecordLocator.locate(
      sourceURL: photo, directory: support.appendingPathComponent("Edits"))
    defer {
      try? FileManager.default.removeItem(at: location.pathURL)
      if location.primaryURL != location.pathURL {
        try? FileManager.default.removeItem(at: location.primaryURL)
      }
    }
    let before = PhotoEdits()
    var after = before
    after.shotExposure = 1.25
    let pending = PendingHistory(changes: [
      PendingChange(
        path: photo.path, location: location, before: before, after: after)
    ])
    try SavedEditStore.save(before, to: location.pathURL)
    if location.primaryURL != location.pathURL {
      try SavedEditStore.save(before, to: location.primaryURL)
    }
    try SavedEditStore.save(pending, to: history)
    let interruptedBeforeWrite = PhotoEditor()
    XCTAssertEqual(interruptedBeforeWrite.batchChangedPaths, [photo.path])
    XCTAssertTrue(interruptedBeforeWrite.undoLastBatch().contains("Restored settings on 0 photos"))
    XCTAssertFalse(interruptedBeforeWrite.canUndoBatch)

    try SavedEditStore.save(after, to: location.pathURL)
    if location.primaryURL != location.pathURL {
      try SavedEditStore.save(after, to: location.primaryURL)
    }
    try SavedEditStore.save(pending, to: history)
    let interruptedAfterWrite = PhotoEditor()
    XCTAssertTrue(interruptedAfterWrite.undoLastBatch().contains("Restored settings on 1 photo"))
    let restored = try JSONDecoder().decode(
      PhotoEdits.self, from: Data(contentsOf: location.pathURL))
    XCTAssertEqual(restored, before)
    XCTAssertFalse(interruptedAfterWrite.canUndoBatch)

    if location.primaryURL != location.pathURL {
      try SavedEditStore.save(after, to: location.pathURL)
      try SavedEditStore.save(before, to: location.primaryURL)
      try SavedEditStore.save(pending, to: history)
      let interruptedBetweenRecords = PhotoEditor()
      XCTAssertTrue(
        interruptedBetweenRecords.undoLastBatch().contains("Restored settings on 0 photos"))
      let repairedPath = try JSONDecoder().decode(
        PhotoEdits.self, from: Data(contentsOf: location.pathURL))
      XCTAssertEqual(repairedPath, before)
      XCTAssertFalse(interruptedBetweenRecords.canUndoBatch)
    }
  }

  @MainActor func testCancelKeepsCompletedEditUndoableAndLeavesNextPhotoUntouched() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-batch-cancel-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("source.jpg")
    let first = root.appendingPathComponent("first.jpg")
    let second = root.appendingPathComponent("second.jpg")
    for url in [source, first, second] { try writeJPEG(to: url) }

    let history = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("FilmLab/BatchHistory.json")
    let previousHistory = try? Data(contentsOf: history)
    defer {
      if let previousHistory {
        try? previousHistory.write(to: history, options: .atomic)
      } else {
        try? FileManager.default.removeItem(at: history)
      }
    }
    let editsDirectory = history.deletingLastPathComponent()
      .appendingPathComponent("Edits", isDirectory: true)
    let backupsDirectory = editsDirectory.appendingPathComponent(
      "BatchBackups", isDirectory: true)
    let previousBackups = Set(
      (try? FileManager.default.contentsOfDirectory(
        at: backupsDirectory, includingPropertiesForKeys: nil)) ?? [])
    defer {
      let current = Set(
        (try? FileManager.default.contentsOfDirectory(
          at: backupsDirectory, includingPropertiesForKeys: nil)) ?? [])
      for url in current.subtracting(previousBackups) {
        try? FileManager.default.removeItem(at: url)
      }
    }
    let firstLocation = EditRecordLocator.locate(sourceURL: first, directory: editsDirectory)
    let secondLocation = EditRecordLocator.locate(sourceURL: second, directory: editsDirectory)
    defer {
      for record in [
        firstLocation.primaryURL, firstLocation.pathURL,
        secondLocation.primaryURL, secondLocation.pathURL,
      ] { try? FileManager.default.removeItem(at: record) }
    }

    let editor = PhotoEditor()
    editor.sourceURL = source
    editor.stockIndex = 2
    editor.shotExposure = 1.25
    editor.copyWorkspace(.film)
    let task = Task { @MainActor in
      await editor.pasteSettings(to: [first.path, second.path], workspaceOnly: true) {
        current, _ in
        if current == 2 {
          XCTAssertEqual(PhotoEditor().batchChangedPaths, [first.path])
          withUnsafeCurrentTask { $0?.cancel() }
        }
      }
    }
    let outcome = await task.value
    XCTAssertTrue(outcome.cancelled)
    XCTAssertEqual(outcome.changedPaths, [first.path])
    XCTAssertTrue(outcome.summary.contains("stopped"))
    XCTAssertEqual(editor.batchChangedPaths, [first.path])
    let firstEdits = try JSONDecoder().decode(
      PhotoEdits.self, from: Data(contentsOf: firstLocation.pathURL))
    XCTAssertEqual(firstEdits.shotExposure, 1.25)
    XCTAssertFalse(FileManager.default.fileExists(atPath: secondLocation.pathURL.path))

    let undo = editor.undoLastBatch()
    XCTAssertTrue(undo.contains("Restored settings on 1 photo"), undo)
    let restored = try JSONDecoder().decode(
      PhotoEdits.self, from: Data(contentsOf: firstLocation.pathURL))
    XCTAssertEqual(restored.shotExposure, 0)
    XCTAssertFalse(editor.canUndoBatch)
  }

  private func writeJPEG(to url: URL) throws {
    let image = CIImage(color: CIColor(red: 0.3, green: 0.4, blue: 0.5))
      .cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
    let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
    let data = try XCTUnwrap(CIContext().jpegRepresentation(of: image, colorSpace: space))
    try data.write(to: url)
  }
}

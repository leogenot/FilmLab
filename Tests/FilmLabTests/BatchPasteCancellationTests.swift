import Foundation
import XCTest

@testable import FilmLab

final class BatchPasteCancellationTests: XCTestCase {
  @MainActor func testCancelKeepsCompletedEditUndoableAndLeavesNextPhotoUntouched() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-batch-cancel-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("source.jpg")
    let first = root.appendingPathComponent("first.jpg")
    let second = root.appendingPathComponent("second.jpg")
    for url in [source, first, second] { try Data("photo".utf8).write(to: url) }

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
        if current == 2 { withUnsafeCurrentTask { $0?.cancel() } }
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
}

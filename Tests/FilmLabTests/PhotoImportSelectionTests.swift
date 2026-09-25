import Foundation
import XCTest

@testable import FilmLab

final class PhotoImportSelectionTests: XCTestCase {
  func testClassifiesMixedFinderSelectionWithoutDuplicatesOrSymlinks() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-import-selection-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let folder = root.appendingPathComponent("Collection")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let raw = root.appendingPathComponent("one.ARW")
    let jpeg = root.appendingPathComponent("two.jpg")
    let text = root.appendingPathComponent("notes.txt")
    let link = root.appendingPathComponent("linked.jpg")
    for url in [raw, jpeg, text] { try Data("test".utf8).write(to: url) }
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: jpeg)

    let selection = PhotoImportSelection(urls: [raw, raw, jpeg, folder, text, link])
    XCTAssertEqual(selection.photos, [raw, jpeg])
    XCTAssertEqual(selection.folders.map(\.path), [folder.path])
    XCTAssertEqual(selection.ignoredCount, 3)
  }
}

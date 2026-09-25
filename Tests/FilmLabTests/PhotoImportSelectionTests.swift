import CoreImage
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
    let first = root.appendingPathComponent("one.jpg")
    let jpeg = root.appendingPathComponent("two.jpg")
    let text = root.appendingPathComponent("notes.txt")
    let impostor = root.appendingPathComponent("impostor.jpg")
    let link = root.appendingPathComponent("linked.jpg")
    for url in [first, jpeg] { try writeJPEG(to: url) }
    for url in [text, impostor] { try Data("test".utf8).write(to: url) }
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: jpeg)

    let selection = PhotoImportSelection(urls: [first, first, jpeg, folder, text, impostor, link])
    XCTAssertEqual(selection.photos, [first, jpeg])
    XCTAssertEqual(selection.folders.map(\.path), [folder.path])
    XCTAssertEqual(selection.ignoredCount, 4)
  }

  func testActualRAWHeaderIsAcceptedWhenAvailable() throws {
    guard let path = ProcessInfo.processInfo.environment["FILMLAB_TEST_RAW"] else {
      throw XCTSkip("Set FILMLAB_TEST_RAW to a disposable RAW photo")
    }
    let raw = URL(fileURLWithPath: path)
    XCTAssertTrue(PhotoFileSupport.hasImageHeader(raw))
    XCTAssertEqual(PhotoImportSelection(urls: [raw]).photos, [raw.standardizedFileURL])
  }

  func testCancelledClassificationDoesNotReturnPartialImport() async {
    let result = await Task.detached {
      withUnsafeCurrentTask { $0?.cancel() }
      return PhotoImportSelection.cancellable(urls: [URL(fileURLWithPath: "/tmp/photo.jpg")])
    }.value
    XCTAssertNil(result)
  }

  func testCancellationAfterFirstEntryDiscardsPartialSelection() {
    var checks = 0
    let selection = PhotoImportSelection.cancellable(
      urls: [URL(fileURLWithPath: "/tmp"), URL(fileURLWithPath: "/tmp/second.jpg")],
      isCancelled: {
        checks += 1
        return checks > 1
      })
    XCTAssertNil(selection)
  }

  private func writeJPEG(to url: URL) throws {
    let image = CIImage(color: CIColor(red: 0.3, green: 0.4, blue: 0.5))
      .cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
    let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
    let data = try XCTUnwrap(CIContext().jpegRepresentation(of: image, colorSpace: space))
    try data.write(to: url)
  }
}

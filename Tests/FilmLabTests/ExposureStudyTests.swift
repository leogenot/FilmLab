import AppKit
import XCTest

@testable import FilmLab

final class ExposureStudyTests: XCTestCase {
  @MainActor func testStudyUsesStockAtFiveStopsForRAWAndJPEG() async throws {
    guard let rawPath = ProcessInfo.processInfo.environment["FILMLAB_TEST_RAW"],
      let jpegPath = ProcessInfo.processInfo.environment["FILMLAB_TEST_JPEG"]
    else { throw XCTSkip("Set FILMLAB_TEST_RAW and FILMLAB_TEST_JPEG to disposable photos") }

    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-exposure-study-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let editsDirectory = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("FilmLab/Edits", isDirectory: true)
    var editRecords: [URL] = []
    defer {
      for record in editRecords { try? FileManager.default.removeItem(at: record) }
      try? FileManager.default.removeItem(at: directory)
    }

    for (kind, path) in [("RAW", rawPath), ("JPEG", jpegPath)] {
      let original = URL(fileURLWithPath: path)
      let input = directory.appendingPathComponent("\(kind).\(original.pathExtension)")
      try FileManager.default.copyItem(at: original, to: input)
      let location = EditRecordLocator.locate(sourceURL: input, directory: editsDirectory)
      editRecords.append(contentsOf: [location.primaryURL, location.pathURL])

      let editor = PhotoEditor()
      editor.open(input)
      try await waitUntil { !editor.isOpening && editor.preview != nil }
      XCTAssertNil(editor.error)
      editor.stockIndex = kind == "RAW" ? 1 : 2
      editor.highPrecisionPreview = true
      editor.editsChanged()
      try await waitUntil { !editor.isRendering && editor.preview != nil }
      editor.buildExposureStudy()
      try await waitUntil {
        !editor.isBuildingExposureStudy && editor.exposureStudyFrames.count == 5
      }
      XCTAssertNil(editor.error)
      XCTAssertEqual(editor.exposureStudyFrames.map(\.ev), [-2, -1, 0, 1, 2])
      for frame in editor.exposureStudyFrames {
        let image = try XCTUnwrap(
          frame.image.cgImage(
            forProposedRect: nil, context: nil, hints: nil))
        XCTAssertEqual(image.bitsPerComponent, 16)
      }
      let dark = try XCTUnwrap(
        editor.exposureStudyFrames.first?.image.cgImage(
          forProposedRect: nil, context: nil, hints: nil)?.dataProvider?.data as Data?)
      let light = try XCTUnwrap(
        editor.exposureStudyFrames.last?.image.cgImage(
          forProposedRect: nil, context: nil, hints: nil)?.dataProvider?.data as Data?)
      XCTAssertNotEqual(dark, light, "\(kind) stock exposure frames were identical")
      editor.chooseExposureStudy(1)
      XCTAssertEqual(editor.shotExposure, 1)
      XCTAssertTrue(editor.exposureStudyFrames.isEmpty)
      try await waitUntil { !editor.isRendering && editor.preview != nil }
      XCTAssertNil(editor.error)
      editor.highPrecisionPreview = false
      editor.buildExposureStudy()
      try await waitUntil {
        !editor.isBuildingExposureStudy && editor.exposureStudyFrames.count == 5
      }
      for frame in editor.exposureStudyFrames {
        let image = try XCTUnwrap(
          frame.image.cgImage(
            forProposedRect: nil, context: nil, hints: nil))
        XCTAssertEqual(image.bitsPerComponent, 8)
      }
      editor.buildExposureStudy()
      editor.shotExposure = -0.5
      editor.editsChanged()
      try await Task.sleep(for: .milliseconds(150))
      XCTAssertFalse(editor.isBuildingExposureStudy)
      XCTAssertTrue(editor.exposureStudyFrames.isEmpty)
      XCTAssertTrue(editor.closePhoto())
      XCTAssertFalse(editor.isBuildingExposureStudy)
    }
  }

  @MainActor private func waitUntil(
    _ condition: @escaping @MainActor () -> Bool
  ) async throws {
    for _ in 0..<600 {
      if condition() { return }
      try await Task.sleep(for: .milliseconds(100))
    }
    XCTFail("Timed out waiting for exposure study")
  }
}

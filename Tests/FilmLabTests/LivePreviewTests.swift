import AppKit
import XCTest

@testable import FilmLab

final class LivePreviewTests: XCTestCase {
  @MainActor func testSliderShowsIntermediateFramesBeforeRelease() async throws {
    guard let jpegPath = ProcessInfo.processInfo.environment["FILMLAB_TEST_JPEG"] else {
      throw XCTSkip("Set FILMLAB_TEST_JPEG to a disposable photo")
    }
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-live-preview-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let input = directory.appendingPathComponent("Live.jpg")
    try FileManager.default.copyItem(atPath: jpegPath, toPath: input.path)
    let editsDirectory = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("FilmLab/Edits", isDirectory: true)
    let location = EditRecordLocator.locate(sourceURL: input, directory: editsDirectory)
    let defaults = UserDefaults.standard
    let previousRecent = defaults.object(forKey: "FilmLab.recentPhotos")
    let previousLast = defaults.object(forKey: "FilmLab.lastPhotoPath")
    defer {
      try? FileManager.default.removeItem(at: location.primaryURL)
      try? FileManager.default.removeItem(at: location.pathURL)
      try? FileManager.default.removeItem(at: directory)
      if let previousRecent {
        defaults.set(previousRecent, forKey: "FilmLab.recentPhotos")
      } else {
        defaults.removeObject(forKey: "FilmLab.recentPhotos")
      }
      if let previousLast {
        defaults.set(previousLast, forKey: "FilmLab.lastPhotoPath")
      } else {
        defaults.removeObject(forKey: "FilmLab.lastPhotoPath")
      }
    }

    let editor = PhotoEditor()
    editor.open(input)
    try await waitUntil("initial") {
      !editor.isOpening && !editor.isRendering && editor.preview != nil
    }
    XCTAssertNil(editor.error)

    editor.sliderEditingChanged(true)
    editor.exposure = -2
    editor.editsChanged()
    try await waitUntil("first drag frame") {
      !editor.isRendering && self.longEdge(editor.preview) == 1000
    }
    let dark = try imageData(editor.preview)

    editor.exposure = 2
    editor.editsChanged()
    try await waitUntil("second drag frame") {
      guard let current = try? self.imageData(editor.preview) else { return false }
      return current != dark && self.longEdge(editor.preview) == 1000
    }
    XCTAssertNil(editor.error)

    editor.sliderEditingChanged(false)
    try await waitUntil("released frame") {
      !editor.isRendering && self.longEdge(editor.preview) == 1800
    }
    XCTAssertNotNil(editor.histogram)
    XCTAssertTrue(editor.closePhoto())
  }

  @MainActor private func imageData(_ image: NSImage?) throws -> Data {
    let cgImage = try XCTUnwrap(image?.cgImage(forProposedRect: nil, context: nil, hints: nil))
    return try XCTUnwrap(cgImage.dataProvider?.data as Data?)
  }

  @MainActor private func longEdge(_ image: NSImage?) -> CGFloat? {
    image.map { max($0.size.width, $0.size.height) }
  }

  @MainActor private func waitUntil(
    _ stage: String, timeout: Duration = .seconds(20), condition: () -> Bool
  ) async throws {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
      guard ContinuousClock.now < deadline else {
        throw NSError(
          domain: "FilmLab.LivePreviewTests", code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for \(stage)"])
      }
      try await Task.sleep(for: .milliseconds(40))
    }
  }
}

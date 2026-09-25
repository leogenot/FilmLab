import Foundation
import XCTest

@testable import FilmLab

final class SRGBCompressionSettingsTests: XCTestCase {
  func testCompressionFollowsPhotoGradeAndDevelopTransfer() throws {
    var copied = PhotoEdits()
    copied.compressSRGBGamut = true
    let destination = PhotoEdits()

    XCTAssertTrue(PhotoEdits.transferring(copied, onto: destination).compressSRGBGamut)
    XCTAssertTrue(
      PhotoEdits.transferring(copied, panel: .develop, onto: destination).compressSRGBGamut)
    XCTAssertFalse(
      PhotoEdits.transferring(copied, panel: .color, onto: destination).compressSRGBGamut)
    XCTAssertFalse(copied.resetting(.develop, isRAW: false).compressSRGBGamut)

    let reopened = try JSONDecoder().decode(PhotoEdits.self, from: JSONEncoder().encode(copied))
    XCTAssertTrue(reopened.compressSRGBGamut)
    let legacy = try JSONDecoder().decode(PhotoEdits.self, from: Data("{}".utf8))
    XCTAssertEqual(
      legacy.compressSRGBGamut,
      UserDefaults.standard.bool(forKey: "FilmLab.compressSRGBGamut"))
  }

  @MainActor func testRAWAndJPEGKeepSeparateSavedCompressionChoices() async throws {
    guard let rawPath = ProcessInfo.processInfo.environment["FILMLAB_TEST_RAW"],
      let jpegPath = ProcessInfo.processInfo.environment["FILMLAB_TEST_JPEG"]
    else { throw XCTSkip("Set FILMLAB_TEST_RAW and FILMLAB_TEST_JPEG to disposable images") }

    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-compression-settings-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let raw = directory.appendingPathComponent("Source.ARW")
    let jpeg = directory.appendingPathComponent("Source.jpg")
    try FileManager.default.copyItem(atPath: rawPath, toPath: raw.path)
    try FileManager.default.copyItem(atPath: jpegPath, toPath: jpeg.path)
    let editsDirectory = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("FilmLab/Edits", isDirectory: true)
    let locations = [raw, jpeg].map {
      EditRecordLocator.locate(sourceURL: $0, directory: editsDirectory)
    }
    let defaults = UserDefaults.standard
    let previousRecent = defaults.object(forKey: "FilmLab.recentPhotos")
    let previousLast = defaults.object(forKey: "FilmLab.lastPhotoPath")
    defer {
      for location in locations {
        try? FileManager.default.removeItem(at: location.primaryURL)
        try? FileManager.default.removeItem(at: location.pathURL)
      }
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
    editor.open(raw)
    try await waitUntil { !editor.isOpening && editor.sourceURL == raw }
    XCTAssertNil(editor.error)
    editor.compressSRGBGamut = true
    editor.editsChanged()
    XCTAssertTrue(editor.flushEdits())

    editor.open(jpeg)
    try await waitUntil { !editor.isOpening && editor.sourceURL == jpeg }
    XCTAssertNil(editor.error)
    XCTAssertFalse(editor.compressSRGBGamut)
    XCTAssertTrue(editor.flushEdits())

    editor.open(raw)
    try await waitUntil { !editor.isOpening && editor.sourceURL == raw }
    XCTAssertNil(editor.error)
    XCTAssertTrue(editor.compressSRGBGamut)
    XCTAssertTrue(editor.closePhoto())

    let rawSaved = try JSONDecoder().decode(
      PhotoEdits.self, from: Data(contentsOf: locations[0].primaryURL))
    let jpegSaved = try JSONDecoder().decode(
      PhotoEdits.self, from: Data(contentsOf: locations[1].primaryURL))
    XCTAssertTrue(rawSaved.compressSRGBGamut)
    XCTAssertFalse(jpegSaved.compressSRGBGamut)
  }

  @MainActor private func waitUntil(
    _ condition: @escaping @MainActor () -> Bool
  ) async throws {
    for _ in 0..<300 {
      if condition() { return }
      try await Task.sleep(for: .milliseconds(100))
    }
    XCTFail("Timed out waiting for the editor")
  }
}

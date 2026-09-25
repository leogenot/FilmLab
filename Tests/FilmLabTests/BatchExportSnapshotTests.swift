import CoreImage
import Foundation
import XCTest

@testable import FilmLab

final class BatchExportSnapshotTests: XCTestCase {
  @MainActor func testOpenPhotoUsesStartOfBatchSettingsSnapshot() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-export-snapshot-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let photo = root.appendingPathComponent("scene.jpg")
    let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
    let image = CIImage(color: CIColor(red: 0.2, green: 0.35, blue: 0.5))
      .cropped(to: CGRect(x: 0, y: 0, width: 96, height: 64))
    let context = CIContext()
    let jpeg = try XCTUnwrap(context.jpegRepresentation(of: image, colorSpace: colorSpace))
    try jpeg.write(to: photo)

    let defaults = UserDefaults.standard
    let previousRecent = defaults.object(forKey: "FilmLab.recentPhotos")
    let previousLast = defaults.object(forKey: "FilmLab.lastPhotoPath")
    let editsDirectory = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("FilmLab/Edits")
    let location = EditRecordLocator.locate(sourceURL: photo, directory: editsDirectory)
    defer {
      try? FileManager.default.removeItem(at: location.primaryURL)
      try? FileManager.default.removeItem(at: location.pathURL)
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
    editor.open(photo)
    for _ in 0..<100 where editor.isOpening || editor.sourceURL != photo {
      try await Task.sleep(for: .milliseconds(30))
    }
    XCTAssertEqual(editor.sourceURL, photo)
    editor.shotExposure = -1
    let baseline = root.appendingPathComponent("baseline", isDirectory: true)
    let inFlight = root.appendingPathComponent("in-flight", isDirectory: true)
    let later = root.appendingPathComponent("later", isDirectory: true)
    for folder in [baseline, inFlight, later] {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }
    let first = await editor.exportBatch([photo.path], to: baseline, format: .tiff16SRGB) { _, _ in
    }
    XCTAssertTrue(first.contains("Exported 1 photo"), first)
    let second = await editor.exportBatch([photo.path], to: inFlight, format: .tiff16SRGB) {
      _, _ in
      editor.shotExposure = 2
      XCTAssertTrue(editor.flushEdits())
    }
    XCTAssertTrue(second.contains("Exported 1 photo"), second)
    let third = await editor.exportBatch([photo.path], to: later, format: .tiff16SRGB) { _, _ in }
    XCTAssertTrue(third.contains("Exported 1 photo"), third)

    func center(_ directory: URL) throws -> [Float] {
      let output = directory.appendingPathComponent("scene-FilmLab.tiff")
      let exported = try XCTUnwrap(CIImage(contentsOf: output))
      let bounds = CGRect(x: 48, y: 32, width: 1, height: 1)
      var pixel = [Float](repeating: 0, count: 4)
      pixel.withUnsafeMutableBytes { bytes in
        context.render(
          exported, toBitmap: bytes.baseAddress!, rowBytes: 4 * MemoryLayout<Float>.size,
          bounds: bounds, format: .RGBAf, colorSpace: colorSpace)
      }
      return pixel
    }
    let before = try center(baseline)
    let during = try center(inFlight)
    let after = try center(later)
    for channel in 0..<3 {
      XCTAssertEqual(during[channel], before[channel], accuracy: 0.002)
    }
    XCTAssertGreaterThan(
      zip(before.prefix(3), after.prefix(3)).map { abs($0 - $1) }.max() ?? 0, 0.03)
    XCTAssertTrue(editor.closePhoto())
  }
}

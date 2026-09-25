import CoreImage
import XCTest

@testable import FilmLab

final class EditorParityTests: XCTestCase {
  @MainActor func testCompleteEditorPreviewAgainstTIFF() async throws {
    guard let rawPath = ProcessInfo.processInfo.environment["FILMLAB_TEST_RAW"],
      let jpegPath = ProcessInfo.processInfo.environment["FILMLAB_TEST_JPEG"]
    else { throw XCTSkip("Set FILMLAB_TEST_RAW and FILMLAB_TEST_JPEG to disposable images") }

    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-full-graph-parity-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let defaults = UserDefaults.standard
    let previousRecent = defaults.object(forKey: "FilmLab.recentPhotos")
    let previousLast = defaults.object(forKey: "FilmLab.lastPhotoPath")
    let editsDirectory = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("FilmLab/Edits", isDirectory: true)
    var records: [URL] = []
    defer {
      for record in records { try? FileManager.default.removeItem(at: record) }
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

    for (kind, path) in [("RAW", rawPath), ("JPEG", jpegPath)] {
      let original = URL(fileURLWithPath: path)
      let input = directory.appendingPathComponent("\(kind).\(original.pathExtension)")
      try FileManager.default.copyItem(at: original, to: input)
      let location = EditRecordLocator.locate(sourceURL: input, directory: editsDirectory)
      records.append(contentsOf: [location.primaryURL, location.pathURL])

      let editor = PhotoEditor()
      editor.open(input)
      try await waitUntil {
        !editor.isOpening && editor.sourceURL == input && editor.preview != nil
      }
      XCTAssertNil(editor.error)
      editor.highPrecisionPreview = true
      if kind == "JPEG" {
        editor.inputTone = 1.15
        editor.inputWarmth = 0.1
      }
      editor.stockIndex = 2
      editor.premierPaperTone = true
      editor.paperExposure = 0.15
      editor.paperStrength = 0.65
      editor.shotExposure = 0.45
      editor.shadowLight = 0.2
      editor.filmLightWarmth = 0.1
      editor.exposure = -0.2
      editor.curveShadow = 0.12
      editor.vibrance = 0.15
      editor.shadowStrength = 0.12
      editor.selectiveShift = 0.1
      editor.mixer[3].saturation = 0.12
      editor.channelCurves[0].midtone = 0.08
      editor.channelCurves[2].shadow = -0.05
      editor.grain = 0.12
      editor.grainSize = 1
      editor.halation = 0.2
      editor.acutance = 0.15
      editor.outputShoulder = 0.15
      editor.radialLights = [
        RadialAdjustment(
          exposure: 0.35, warmth: 0.1, saturation: -0.2,
          centerX: 0.52, centerY: 0.46,
          radius: 0.3, feather: 0.6, toneRangeEnabled: true,
          toneCenter: 0, toneWidth: 4, toneFeather: 1,
          hueRangeEnabled: true, hueCenter: 210,
          hueWidth: 60, hueFeather: 20)
      ]
      for scenario in ["rotatedPortrait", "darkFreeCrop", "brightWideCrop", "tallPortrait"] {
        switch scenario {
        case "darkFreeCrop":
          editor.shotExposure = -1.5
          editor.shadowLight = 0.6
          editor.highlightLight = 0
          editor.frameRotation = 3
          editor.frameStraighten = 8
          editor.frameAspect = 5
          editor.frameFreeCrop = FreeCrop(
            centerX: 0.39, centerY: 0.58, width: 0.63, height: 0.73)
        case "brightWideCrop":
          editor.shotExposure = 1.25
          editor.shadowLight = -0.2
          editor.highlightLight = -0.4
          editor.frameRotation = 0
          editor.frameStraighten = -6
          editor.frameAspect = 4
          editor.frameOffsetX = 0.6
          editor.frameOffsetY = -0.35
        case "tallPortrait":
          editor.shotExposure = 0.6
          editor.shadowLight = 0.1
          editor.highlightLight = -0.1
          editor.frameRotation = 0
          editor.frameStraighten = 4
          editor.frameAspect = 7
          editor.frameOffsetX = -0.6
          editor.frameOffsetY = 0.25
        default:
          editor.frameRotation = 1
          editor.frameAspect = 2
        }
        editor.preview = nil
        editor.editsChanged()
        try await waitUntil { !editor.isRendering && editor.preview != nil }
        XCTAssertNil(editor.error)

        let preview = try XCTUnwrap(editor.preview)
        let previewImage = try XCTUnwrap(
          preview.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let outputDirectory = directory.appendingPathComponent("\(kind)-\(scenario)")
        try FileManager.default.createDirectory(
          at: outputDirectory, withIntermediateDirectories: true)
        let summary = await editor.exportBatch(
          [input.path], to: outputDirectory, format: .tiff16SRGB
        ) { _, _ in }
        XCTAssertTrue(summary.contains("Exported 1 photo"), summary)
        let output = outputDirectory.appendingPathComponent("\(kind)-FilmLab.tiff")
        let exported = try XCTUnwrap(CIImage(contentsOf: output))
        XCTAssertEqual(
          Double(previewImage.width) / Double(previewImage.height),
          Double(exported.extent.width / exported.extent.height), accuracy: 0.005)
        let difference = compare(preview: previewImage, export: exported)
        print(
          "Full graph \(kind) \(scenario): mean \(difference.mean), max \(difference.maximum) / 255"
        )
        XCTAssertLessThan(
          difference.mean, 2.5, "\(kind) \(scenario) preview/export color drift")
      }
      let savedData = try Data(contentsOf: location.primaryURL)
      let saved = try XCTUnwrap(
        JSONSerialization.jsonObject(with: savedData) as? [String: Any])
      let areas = try XCTUnwrap(saved["radialLights"] as? [[String: Any]])
      let area = try XCTUnwrap(areas.first)
      XCTAssertEqual(area["toneRangeEnabled"] as? Bool, true)
      XCTAssertEqual(area["toneWidth"] as? Double, 4)
      XCTAssertEqual(area["hueRangeEnabled"] as? Bool, true)
      XCTAssertEqual(area["hueCenter"] as? Double, 210)
      XCTAssertEqual(area["saturation"] as? Double, -0.2)
    }
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

  private func compare(preview: CGImage, export: CIImage) -> (
    mean: Double, maximum: Int
  ) {
    let width = preview.width
    let height = preview.height
    let context = CIContext(options: [
      .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
      .workingFormat: CIFormat.RGBAf,
    ])
    let bounds = CGRect(x: 0, y: 0, width: width, height: height)
    let scale = min(1, 1800 / max(export.extent.width, export.extent.height))
    let reduced = export.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    func pixels(_ image: CIImage) -> [UInt8] {
      var result = [UInt8](repeating: 0, count: width * height * 4)
      result.withUnsafeMutableBytes { bytes in
        context.render(
          image, toBitmap: bytes.baseAddress!, rowBytes: width * 4,
          bounds: bounds, format: .RGBA8, colorSpace: space)
      }
      return result
    }
    let previewPixels = pixels(CIImage(cgImage: preview))
    let exportPixels = pixels(reduced)
    var total = 0
    var maximum = 0
    for offset in stride(from: 0, to: previewPixels.count, by: 4) {
      for channel in 0..<3 {
        let difference = abs(
          Int(previewPixels[offset + channel]) - Int(exportPixels[offset + channel]))
        total += difference
        maximum = max(maximum, difference)
      }
    }
    return (Double(total) / Double(width * height * 3), maximum)
  }
}

import CoreImage
import XCTest

@testable import FilmLab

final class ZoomTileTests: XCTestCase {
  @MainActor func testEditorRendersAndScrollsBoundedRAWTile() async throws {
    guard let rawPath = ProcessInfo.processInfo.environment["FILMLAB_TEST_RAW"] else {
      throw XCTSkip("Set FILMLAB_TEST_RAW to a disposable RAW photo")
    }
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-zoom-tile-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let input = directory.appendingPathComponent("Tile.arw")
    try FileManager.default.copyItem(atPath: rawPath, toPath: input.path)
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
    try await waitUntil { !editor.isOpening && !editor.isRendering && editor.preview != nil }
    editor.toggleZoom()
    try await waitUntil { !editor.isRendering && editor.preview != nil }
    let firstTile = editor.zoomTileRect
    XCTAssertGreaterThan(editor.zoomCanvasSize.width, firstTile.width)
    XCTAssertGreaterThan(editor.zoomCanvasSize.height, firstTile.height)
    XCTAssertEqual(editor.preview?.size.width, firstTile.width)
    XCTAssertGreaterThan(try meanRGB(editor.preview), 0.02)

    editor.updateZoomViewport(
      offset: CGPoint(x: 1500, y: 1900), size: CGSize(width: 600, height: 400),
      displayScale: 2)
    try await waitUntil { !editor.isRendering && editor.zoomTileRect != firstTile }
    XCTAssertEqual(editor.preview?.size.width, editor.zoomTileRect.width)
    XCTAssertGreaterThan(try meanRGB(editor.preview), 0.02)
    XCTAssertTrue(
      editor.zoomTileRect.contains(
        CGRect(x: 3000, y: 3800, width: 1200, height: 800)))

    let scrolledTile = editor.zoomTileRect
    editor.updateZoomViewport(
      offset: CGPoint(x: 3000, y: 2500), size: CGSize(width: 400, height: 300),
      displayScale: 2, zoomScale: 2)
    try await waitUntil { !editor.isRendering && editor.zoomTileRect != scrolledTile }
    XCTAssertTrue(
      editor.zoomTileRect.contains(
        CGRect(x: 3000, y: 2500, width: 400, height: 300)))
    XCTAssertTrue(editor.closePhoto())
  }

  func testTileCoversViewportAndMovesOnScroll() {
    let canvas = CGSize(width: 7008, height: 4672)
    let first = CGRect(x: 0, y: 0, width: 1200, height: 900)
    let firstTile = ZoomTile.rect(for: first, canvas: canvas)
    XCTAssertTrue(firstTile.contains(first))
    XCTAssertLessThan(firstTile.width * firstTile.height, canvas.width * canvas.height / 4)
    XCTAssertEqual(firstTile, ZoomTile.rect(for: first.offsetBy(dx: 40, dy: 30), canvas: canvas))

    let moved = CGRect(x: 4600, y: 3100, width: 1200, height: 900)
    let movedTile = ZoomTile.rect(for: moved, canvas: canvas)
    XCTAssertTrue(movedTile.contains(moved))
    XCTAssertNotEqual(firstTile, movedTile)
    XCTAssertLessThanOrEqual(movedTile.maxX, canvas.width)
    XCTAssertLessThanOrEqual(movedTile.maxY, canvas.height)
  }

  func testCropRendersOnlyRequestedRegion() async throws {
    let source = CIImage(color: .init(red: 0.35, green: 0.5, blue: 0.75))
      .cropped(to: CGRect(x: 0, y: 0, width: 2048, height: 1536))
    let crop = CGRect(x: 512, y: 256, width: 768, height: 640)
    let renderer = PreviewRenderer()
    let result = await renderer.render(
      PreviewRequest(
        image: source, scale: 1, sourceURL: nil, originalImage: nil,
        showGamutWarning: false, cropRect: crop))
    XCTAssertEqual(result?.image.width, Int(crop.width))
    XCTAssertEqual(result?.image.height, Int(crop.height))
    XCTAssertNotNil(result?.histogram)
    if let image = result?.image {
      let bitmap = NSBitmapImageRep(cgImage: image)
      let center = bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)
      XCTAssertGreaterThan(center?.blueComponent ?? 0, 0.5)
    }
  }

  @MainActor private func waitUntil(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + .seconds(30)
    while !condition() {
      guard ContinuousClock.now < deadline else {
        throw NSError(domain: "FilmLab.ZoomTileTests", code: 1)
      }
      try await Task.sleep(for: .milliseconds(50))
    }
  }

  @MainActor private func meanRGB(_ image: NSImage?) throws -> Float {
    let cgImage = try XCTUnwrap(image?.cgImage(forProposedRect: nil, context: nil, hints: nil))
    let bitmap = NSBitmapImageRep(cgImage: cgImage)
    var total: Float = 0
    var count: Float = 0
    for row in 1...7 {
      for column in 1...7 {
        let x = column * (bitmap.pixelsWide - 1) / 8
        let y = row * (bitmap.pixelsHigh - 1) / 8
        guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
        total += Float((color.redComponent + color.greenComponent + color.blueComponent) / 3)
        count += 1
      }
    }
    return count > 0 ? total / count : 0
  }
}

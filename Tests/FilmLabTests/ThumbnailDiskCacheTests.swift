import CoreGraphics
import XCTest

@testable import FilmLab

final class ThumbnailDiskCacheTests: XCTestCase {
  func testDevelopedSignatureChangesWithSourceAndSavedEdits() throws {
    let folder = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-thumbnail-signature-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: folder) }
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let source = folder.appendingPathComponent("scene.jpg")
    let editsDirectory = folder.appendingPathComponent("Edits")
    try Data("source".utf8).write(to: source)
    let original = try XCTUnwrap(
      ThumbnailCacheSignature.developed(for: source, editsDirectory: editsDirectory))

    let editURL = EditRecordLocator.locate(sourceURL: source, directory: editsDirectory).primaryURL
    try FileManager.default.createDirectory(
      at: editURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("grade one".utf8).write(to: editURL)
    let graded = try XCTUnwrap(
      ThumbnailCacheSignature.developed(for: source, editsDirectory: editsDirectory))
    XCTAssertNotEqual(original, graded)

    try Data("grade two".utf8).write(to: editURL, options: .atomic)
    let changedGrade = try XCTUnwrap(
      ThumbnailCacheSignature.developed(for: source, editsDirectory: editsDirectory))
    XCTAssertNotEqual(graded, changedGrade)

    try Data("new source content".utf8).write(to: source, options: .atomic)
    let changedSource = try XCTUnwrap(
      ThumbnailCacheSignature.developed(for: source, editsDirectory: editsDirectory))
    XCTAssertNotEqual(changedGrade, changedSource)
  }

  func testCachedThumbnailIsReadableOnlyForMatchingSignature() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-thumbnail-cache-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let cache = ThumbnailDiskCache(directory: directory, capacity: 1)
    let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try XCTUnwrap(
      CGContext(
        data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
    let image = try XCTUnwrap(context.makeImage())

    cache.save(image, path: "/tmp/scene.jpg", signature: "grade-a")
    XCTAssertEqual(cache.load(path: "/tmp/scene.jpg", signature: "grade-a")?.width, 2)
    XCTAssertNil(cache.load(path: "/tmp/scene.jpg", signature: "grade-b"))
    XCTAssertNil(cache.load(path: "/tmp/other.jpg", signature: "grade-a"))
    cache.save(image, path: "/tmp/other.jpg", signature: "grade-b")
    XCTAssertNil(cache.load(path: "/tmp/scene.jpg", signature: "grade-a"))
    XCTAssertEqual(cache.load(path: "/tmp/other.jpg", signature: "grade-b")?.height, 2)
  }

  func testJSONKeyOrderDoesNotInvalidateDevelopedThumbnail() throws {
    let folder = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-thumbnail-order-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: folder) }
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let source = folder.appendingPathComponent("scene.jpg")
    let editsDirectory = folder.appendingPathComponent("Edits")
    try Data("source".utf8).write(to: source)
    let editURL = EditRecordLocator.locate(sourceURL: source, directory: editsDirectory).primaryURL
    try FileManager.default.createDirectory(
      at: editURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("{\"exposure\":1,\"contrast\":2}".utf8).write(to: editURL)
    let original = try XCTUnwrap(
      ThumbnailCacheSignature.developed(for: source, editsDirectory: editsDirectory))
    try Data("{\"contrast\":2,\"exposure\":1}".utf8).write(to: editURL, options: .atomic)
    XCTAssertEqual(
      original, ThumbnailCacheSignature.developed(for: source, editsDirectory: editsDirectory))
  }
}

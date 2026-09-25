import CoreImage
import XCTest

@testable import FilmLab

final class ThumbnailDecodeTests: XCTestCase {
  func testRAWThumbnailUsesReducedDecoderOutput() async throws {
    guard let path = ProcessInfo.processInfo.environment["FILMLAB_TEST_RAW"] else {
      throw XCTSkip("Set FILMLAB_TEST_RAW to a disposable RAW photo")
    }
    let decoder = ImageDecoder()
    let url = URL(fileURLWithPath: path)
    let full = try await decoder.decode(
      from: url, isRAW: true, flatRAW: true,
      highlightRecovery: false, temperature: nil, tint: nil)
    let thumbnail = try await decoder.decode(
      from: url, isRAW: true, flatRAW: true,
      highlightRecovery: false, temperature: nil, tint: nil, maxDimension: 1024)
    let fullLongest = max(full.image.extent.width, full.image.extent.height)
    let thumbnailLongest = max(thumbnail.image.extent.width, thumbnail.image.extent.height)
    XCTAssertGreaterThan(fullLongest, 1024)
    XCTAssertLessThanOrEqual(thumbnailLongest, 1032)
    XCTAssertGreaterThan(thumbnailLongest, 512)
    XCTAssertEqual(
      full.image.extent.width / full.image.extent.height,
      thumbnail.image.extent.width / thumbnail.image.extent.height,
      accuracy: 0.01)
    XCTAssertEqual(full.cameraTemperature, thumbnail.cameraTemperature)
    XCTAssertEqual(full.cameraTint, thumbnail.cameraTint)
  }

  func testRenderedPhotoKeepsOriginalDimensions() async throws {
    guard let path = ProcessInfo.processInfo.environment["FILMLAB_TEST_JPEG"] else {
      throw XCTSkip("Set FILMLAB_TEST_JPEG to a disposable JPEG photo")
    }
    let decoder = ImageDecoder()
    let url = URL(fileURLWithPath: path)
    let full = try await decoder.decode(
      from: url, isRAW: false, flatRAW: true,
      highlightRecovery: false, temperature: nil, tint: nil)
    let thumbnail = try await decoder.decode(
      from: url, isRAW: false, flatRAW: true,
      highlightRecovery: false, temperature: nil, tint: nil, maxDimension: 1024)
    XCTAssertEqual(full.image.extent, thumbnail.image.extent)
  }
}

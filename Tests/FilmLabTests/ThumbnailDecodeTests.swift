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
    XCTAssertEqual(full.sourceLongestSide, fullLongest, accuracy: 1)
    XCTAssertEqual(thumbnail.sourceLongestSide, fullLongest, accuracy: 1)
    XCTAssertEqual(
      full.image.extent.width / full.image.extent.height,
      thumbnail.image.extent.width / thumbnail.image.extent.height,
      accuracy: 0.01)
    XCTAssertEqual(full.cameraTemperature, thumbnail.cameraTemperature)
    XCTAssertEqual(full.cameraTint, thumbnail.cameraTint)
  }

  func testRenderedThumbnailUsesReducedDecoderOutput() async throws {
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
    let fullLongest = max(full.image.extent.width, full.image.extent.height)
    let thumbnailLongest = max(thumbnail.image.extent.width, thumbnail.image.extent.height)
    XCTAssertGreaterThan(fullLongest, 1024)
    XCTAssertLessThanOrEqual(thumbnailLongest, 1024)
    XCTAssertGreaterThan(thumbnailLongest, 512)
    XCTAssertEqual(full.sourceLongestSide, fullLongest, accuracy: 1)
    XCTAssertEqual(thumbnail.sourceLongestSide, fullLongest, accuracy: 1)
    XCTAssertEqual(
      full.image.extent.width / full.image.extent.height,
      thumbnail.image.extent.width / thumbnail.image.extent.height,
      accuracy: 0.01)
    let context = CIContext(options: [
      .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
      .workingFormat: CIFormat.RGBAf,
    ])
    let targetWidth = max(1, Int(floor(96 * full.image.extent.width / full.image.extent.height)))
    let sampleBounds = CGRect(x: 0, y: 0, width: targetWidth, height: 96)
    func sampledPixels(_ image: CIImage) -> [Float] {
      let reduced = image.applyingFilter(
        "CILanczosScaleTransform",
        parameters: [
          kCIInputScaleKey: 96 / max(image.extent.width, image.extent.height),
          kCIInputAspectRatioKey: 1,
        ])
      let bounds = sampleBounds
      let width = Int(bounds.width)
      let height = Int(bounds.height)
      var pixels = [Float](repeating: 0, count: width * height * 4)
      pixels.withUnsafeMutableBytes { bytes in
        context.render(
          reduced, toBitmap: bytes.baseAddress!, rowBytes: width * 4 * MemoryLayout<Float>.size,
          bounds: bounds, format: .RGBAf,
          colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!)
      }
      return pixels
    }
    let fullPixels = sampledPixels(full.image)
    let thumbnailPixels = sampledPixels(thumbnail.image)
    XCTAssertEqual(fullPixels.count, thumbnailPixels.count)
    let differences = zip(fullPixels, thumbnailPixels).map { abs($0 - $1) }
    XCTAssertLessThan(
      Double(differences.reduce(0, +)) / Double(differences.count), 0.03,
      "Thumbnail decode changed the JPEG's overall color or orientation")
  }
}

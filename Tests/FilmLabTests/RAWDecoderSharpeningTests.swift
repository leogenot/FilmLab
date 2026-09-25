import CoreImage
import XCTest

@testable import FilmLab

final class RAWDecoderSharpeningTests: XCTestCase {
  func testNewRAWDefaultsDisableCameraSharpeningButOlderGradesKeepIt() throws {
    XCTAssertFalse(PhotoEdits.defaults(forRAW: true).rawDecoderSharpening)
    XCTAssertTrue(PhotoEdits.defaults(forRAW: false).rawDecoderSharpening)
    let older = try JSONDecoder().decode(
      PhotoEdits.self, from: Data(#"{"flatRAW":true}"#.utf8))
    XCTAssertTrue(older.rawDecoderSharpening)
    let destination = PhotoEdits.defaults(forRAW: true)
    XCTAssertFalse(
      PhotoEdits.transferring(older, onto: destination).rawDecoderSharpening,
      "Copying a grade should keep the destination RAW decoder setting")
  }

  func testRAWSharpeningControlChangesDecodedEdges() async throws {
    guard let path = ProcessInfo.processInfo.environment["FILMLAB_TEST_RAW"] else {
      throw XCTSkip("Set FILMLAB_TEST_RAW to a disposable RAW image")
    }
    let url = URL(fileURLWithPath: path)
    let decoder = ImageDecoder()
    let camera = try await decoder.decode(
      from: url, isRAW: true, flatRAW: true, highlightRecovery: false,
      decoderSharpening: true, temperature: nil, tint: nil)
    let unsharpened = try await decoder.decode(
      from: url, isRAW: true, flatRAW: true, highlightRecovery: false,
      decoderSharpening: false, temperature: nil, tint: nil)
    XCTAssertTrue(camera.decoderSharpeningSupported)
    XCTAssertEqual(camera.image.extent, unsharpened.image.extent)
    let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
    let context = CIContext(options: [.workingColorSpace: space, .workingFormat: CIFormat.RGBAf])
    let bounds = CGRect(
      x: floor(camera.image.extent.midX) - 128,
      y: floor(camera.image.extent.midY) - 128,
      width: 256, height: 256)
    func pixels(_ image: CIImage) -> [Float] {
      var values = [Float](repeating: 0, count: 256 * 256 * 4)
      values.withUnsafeMutableBytes { bytes in
        context.render(
          image, toBitmap: bytes.baseAddress!, rowBytes: 256 * 4 * MemoryLayout<Float>.size,
          bounds: bounds, format: .RGBAf, colorSpace: space)
      }
      return values
    }
    let before = pixels(camera.image)
    let after = pixels(unsharpened.image)
    let difference = zip(before, after).map { abs($0 - $1) }.max() ?? 0
    XCTAssertGreaterThan(difference, 0.001, "Turning off RAW sharpening did not change edges")
  }
}

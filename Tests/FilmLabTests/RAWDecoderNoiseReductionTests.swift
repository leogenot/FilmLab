import CoreImage
import XCTest

@testable import FilmLab

final class RAWDecoderNoiseReductionTests: XCTestCase {
  func testLegacyAndNewGradesKeepCameraNoiseReduction() throws {
    let defaults = PhotoEdits.defaults(forRAW: true)
    XCTAssertTrue(defaults.rawLuminanceNoiseReduction)
    XCTAssertTrue(defaults.rawColorNoiseReduction)
    let older = try JSONDecoder().decode(
      PhotoEdits.self, from: Data(#"{"flatRAW":true}"#.utf8))
    XCTAssertTrue(older.rawLuminanceNoiseReduction)
    XCTAssertTrue(older.rawColorNoiseReduction)
    var custom = defaults
    custom.rawLuminanceNoiseReduction = false
    custom.rawColorNoiseReduction = false
    let restored = try JSONDecoder().decode(PhotoEdits.self, from: JSONEncoder().encode(custom))
    XCTAssertFalse(restored.rawLuminanceNoiseReduction)
    XCTAssertFalse(restored.rawColorNoiseReduction)
    let transferred = PhotoEdits.transferring(older, onto: custom)
    XCTAssertFalse(transferred.rawLuminanceNoiseReduction)
    XCTAssertFalse(transferred.rawColorNoiseReduction)
  }

  func testIndependentNoiseControlsChangeHighISORAWPixels() async throws {
    guard let path = ProcessInfo.processInfo.environment["FILMLAB_TEST_RAW"] else {
      throw XCTSkip("Set FILMLAB_TEST_RAW to a disposable RAW image")
    }
    let decoder = ImageDecoder()
    let url = URL(fileURLWithPath: path)
    let camera = try await decoder.decode(
      from: url, isRAW: true, flatRAW: true, highlightRecovery: false,
      decoderSharpening: false, temperature: nil, tint: nil)
    let noLuminance = try await decoder.decode(
      from: url, isRAW: true, flatRAW: true, highlightRecovery: false,
      decoderSharpening: false, luminanceNoiseReduction: false,
      temperature: nil, tint: nil)
    let noColor = try await decoder.decode(
      from: url, isRAW: true, flatRAW: true, highlightRecovery: false,
      decoderSharpening: false, colorNoiseReduction: false,
      temperature: nil, tint: nil)
    XCTAssertTrue(camera.luminanceNoiseReductionSupported)
    XCTAssertTrue(camera.colorNoiseReductionSupported)
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
    let baseline = pixels(camera.image)
    let luminanceDifference =
      zip(baseline, pixels(noLuminance.image))
      .map { abs($0 - $1) }.max() ?? 0
    let colorDifference =
      zip(baseline, pixels(noColor.image))
      .map { abs($0 - $1) }.max() ?? 0
    XCTAssertGreaterThan(luminanceDifference, 0.001)
    XCTAssertGreaterThan(colorDifference, 0.001)
  }
}

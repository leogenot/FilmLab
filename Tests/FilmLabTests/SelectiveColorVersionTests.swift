import CoreImage
import XCTest

@testable import FilmLab

final class SelectiveColorVersionTests: XCTestCase {
  func testSavedGradesKeepLegacySelectiveColorUntilUpgrade() throws {
    let legacy = try JSONDecoder().decode(PhotoEdits.self, from: Data("{}".utf8))
    XCTAssertEqual(legacy.selectiveColorVersion, 1)
    XCTAssertEqual(PhotoEdits().selectiveColorVersion, 2)
    XCTAssertEqual(legacy.resetting(.color, isRAW: false).selectiveColorVersion, 1)

    let destination = PhotoEdits.defaults(forRAW: false)
    let transferred = PhotoEdits.transferring(legacy, panel: .color, onto: destination)
    XCTAssertEqual(transferred.selectiveColorVersion, 1)
    let saved = try JSONDecoder().decode(
      PhotoEdits.self, from: JSONEncoder().encode(PhotoEdits()))
    XCTAssertEqual(saved.selectiveColorVersion, 2)
  }

  func testNewSelectiveColorPreservesLuminanceAndNonnegativeChannels() throws {
    let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
    let context = CIContext(options: [
      .workingColorSpace: space,
      .workingFormat: CIFormat.RGBAf,
    ])
    func patch(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> CIImage {
      CIImage(color: CIColor(red: red, green: green, blue: blue, colorSpace: space)!)
        .cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
    }
    func channels(_ image: CIImage) -> [Float] {
      var rgba = [Float](repeating: 0, count: 4)
      rgba.withUnsafeMutableBytes { bytes in
        context.render(
          image, toBitmap: bytes.baseAddress!, rowBytes: 16,
          bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
          format: .RGBAf, colorSpace: space)
      }
      return Array(rgba.prefix(3))
    }
    func luma(_ rgb: [Float]) -> Float {
      0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]
    }
    let input = patch(0.8, 0.12, 0.05)
    let original = channels(input)
    let adjusted = channels(
      SelectiveColor.apply(
        to: input, targetHue: 0, range: 90, hueShift: 45, saturation: 0.5,
        version: 2))
    let legacy = channels(
      SelectiveColor.apply(
        to: input, targetHue: 0, range: 90, hueShift: 45, saturation: 0.5,
        version: 1))
    XCTAssertTrue(adjusted.allSatisfy { $0 >= -0.0001 && $0.isFinite })
    XCTAssertLessThan(abs(luma(adjusted) - luma(original)), 0.0001)
    XCTAssertGreaterThan(
      zip(adjusted, original).map { abs($0 - $1) }.max() ?? 0, 0.01)

    let extended = patch(-0.1, 0.5, 0.2)
    let extendedAdjusted = SelectiveColor.apply(
      to: extended, targetHue: 120, range: 90, hueShift: 40, saturation: 0.8,
      version: 2)
    XCTAssertEqual(channels(extendedAdjusted), channels(extended))
    XCTAssertGreaterThan(
      zip(adjusted, legacy).map { abs($0 - $1) }.max() ?? 0, 0.001)
  }
}

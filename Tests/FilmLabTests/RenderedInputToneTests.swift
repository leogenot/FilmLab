import CoreImage
import XCTest

@testable import FilmLab

final class RenderedInputToneTests: XCTestCase {
  func testToneControlRetainsSignedWideGamutChannels() throws {
    let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
    let context = CIContext(options: [
      .workingColorSpace: space,
      .workingFormat: CIFormat.RGBAf,
    ])
    let source = CIImage(
      color: try XCTUnwrap(CIColor(red: -0.08, green: 0.42, blue: 0.25, colorSpace: space))
    ).cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
    let kernel = try XCTUnwrap(FilmKernels.kernel("renderedInputTone"))
    let toned = try XCTUnwrap(kernel.apply(extent: source.extent, arguments: [source, 0.7]))

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

    let before = channels(source)
    let after = channels(toned)
    XCTAssertLessThan(before[0], -0.05)
    XCTAssertLessThan(after[0], -0.05)
    XCTAssertGreaterThan(abs(after[1] - before[1]), 0.01)
    XCTAssertEqual(after[0] / before[0], after[1] / before[1], accuracy: 0.0001)
    XCTAssertEqual(after[2] / before[2], after[1] / before[1], accuracy: 0.0001)
  }
}

import CoreImage
import Foundation
import XCTest

@testable import FilmLab

final class FilmInputVersionTests: XCTestCase {
  func testWideGamutFilmInputPreservesLuminanceAndChromaDirection() throws {
    let kernel = try XCTUnwrap(FilmKernels.kernel("positiveFilmLight"))
    let bounds = CGRect(x: 0, y: 0, width: 1, height: 1)
    let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
    let source = CIImage(
      color: CIColor(red: 1.2, green: 0.1, blue: -0.2, colorSpace: space)!
    ).cropped(to: bounds)
    let result = try XCTUnwrap(kernel.apply(extent: bounds, arguments: [source]))
    let context = CIContext(options: [.workingColorSpace: space, .workingFormat: CIFormat.RGBAf])
    func channels(_ image: CIImage) -> [Float] {
      var pixels = [Float](repeating: 0, count: 4)
      pixels.withUnsafeMutableBytes { bytes in
        context.render(
          image, toBitmap: bytes.baseAddress!, rowBytes: 4 * MemoryLayout<Float>.size,
          bounds: bounds, format: .RGBAf, colorSpace: space)
      }
      return pixels
    }
    func luminance(_ rgb: [Float]) -> Float {
      rgb[0] * 0.2126 + rgb[1] * 0.7152 + rgb[2] * 0.0722
    }

    let before = channels(source)
    let after = channels(result)
    XCTAssertLessThan(before[2], -0.1)
    let y = luminance(before)
    XCTAssertTrue(after.prefix(3).allSatisfy { $0 >= -0.0001 })
    XCTAssertEqual(luminance(after), y, accuracy: 0.001)
    XCTAssertEqual(after[2], 0, accuracy: 0.001)
    let redScale = (after[0] - y) / (before[0] - y)
    let greenScale = (after[1] - y) / (before[1] - y)
    XCTAssertEqual(redScale, greenScale, accuracy: 0.001)
    XCTAssertLessThan(after[0], before[0])
    let clippedLuminance = before[0] * 0.2126 + before[1] * 0.7152
    XCTAssertGreaterThan(clippedLuminance, y + 0.01)
  }

  func testFilmInputVersionFollowsDevelopSettingsAndPreservesOldGrades() throws {
    let legacy = try JSONDecoder().decode(PhotoEdits.self, from: Data("{}".utf8))
    XCTAssertEqual(legacy.filmInputVersion, 1)
    XCTAssertEqual(PhotoEdits().filmInputVersion, 2)
    XCTAssertEqual(legacy.resetting(.develop, isRAW: false).filmInputVersion, 2)

    let destination = PhotoEdits.defaults(forRAW: false)
    let transferred = PhotoEdits.transferring(legacy, panel: .develop, onto: destination)
    XCTAssertEqual(transferred.filmInputVersion, 1)
    let saved = try JSONDecoder().decode(
      PhotoEdits.self, from: JSONEncoder().encode(PhotoEdits()))
    XCTAssertEqual(saved.filmInputVersion, 2)
  }
}

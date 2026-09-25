import CoreImage
import Foundation
import XCTest

@testable import FilmLab

final class OutputSaturationVersionTests: XCTestCase {
  func testNewSaturationPreservesLuminanceWithoutCreatingNegativeChannels() throws {
    let kernel = try XCTUnwrap(FilmKernels.kernel("localSaturation"))
    let bounds = CGRect(x: 0, y: 0, width: 1, height: 1)
    let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
    let source = CIImage(
      color: CIColor(red: 0.8, green: 0.2, blue: 0.1, colorSpace: space)!
    ).cropped(to: bounds)
    let old = source.applyingFilter(
      "CIColorControls",
      parameters: [kCIInputContrastKey: 1.0, kCIInputSaturationKey: 1.5])
    let new = try XCTUnwrap(kernel.apply(extent: bounds, arguments: [source, 0.5]))
    let neutral = try XCTUnwrap(kernel.apply(extent: bounds, arguments: [source, -1.0]))
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
    func luminance(_ pixels: [Float]) -> Float {
      pixels[0] * 0.2126 + pixels[1] * 0.7152 + pixels[2] * 0.0722
    }

    let oldPixels = channels(old)
    let newPixels = channels(new)
    let neutralPixels = channels(neutral)
    XCTAssertLessThan(oldPixels[2], -0.005)
    XCTAssertGreaterThanOrEqual(newPixels[2], -0.0001)
    XCTAssertEqual(luminance(newPixels), luminance(channels(source)), accuracy: 0.001)
    XCTAssertEqual(neutralPixels[0], neutralPixels[1], accuracy: 0.001)
    XCTAssertEqual(neutralPixels[1], neutralPixels[2], accuracy: 0.001)
  }

  func testOutputSaturationVersionFollowsDevelopSettingsAndPreservesOldGrades() throws {
    let legacy = try JSONDecoder().decode(PhotoEdits.self, from: Data("{}".utf8))
    XCTAssertEqual(legacy.outputSaturationVersion, 1)
    XCTAssertEqual(PhotoEdits().outputSaturationVersion, 2)
    XCTAssertEqual(legacy.resetting(.develop, isRAW: false).outputSaturationVersion, 2)

    let destination = PhotoEdits.defaults(forRAW: false)
    let transferred = PhotoEdits.transferring(legacy, panel: .develop, onto: destination)
    XCTAssertEqual(transferred.outputSaturationVersion, 1)
    let saved = try JSONDecoder().decode(
      PhotoEdits.self, from: JSONEncoder().encode(PhotoEdits()))
    XCTAssertEqual(saved.outputSaturationVersion, 2)
  }
}

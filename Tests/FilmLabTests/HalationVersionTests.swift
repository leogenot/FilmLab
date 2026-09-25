import CoreImage
import Foundation
import XCTest

@testable import FilmLab

final class HalationVersionTests: XCTestCase {
  func testHalationSpillUsesSceneBrightnessRatherThanFinishedTone() throws {
    let bounds = CGRect(x: 0, y: 0, width: 128, height: 64)
    let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
    let base = CIImage(color: CIColor(red: 0.18, green: 0.18, blue: 0.18, colorSpace: space)!)
      .cropped(to: bounds)
    let dark = CIImage(color: CIColor(red: 0.02, green: 0.02, blue: 0.02, colorSpace: space)!)
      .cropped(to: bounds)
    let context = CIContext(options: [.workingColorSpace: space, .workingFormat: CIFormat.RGBAf])
    func edgeValue(light: CGFloat, version: Int) -> Float {
      let stripe = CIImage(
        color: CIColor(red: light, green: light, blue: light, colorSpace: space)!
      )
      .cropped(to: CGRect(x: 56, y: 0, width: 16, height: 64))
      let scene = stripe.composited(over: dark)
      let result = FilmEffects.apply(
        to: base, grain: 0, halation: 1, halationSource: scene, halationVersion: version)
      var pixels = [Float](repeating: 0, count: 4)
      pixels.withUnsafeMutableBytes { bytes in
        context.render(
          result, toBitmap: bytes.baseAddress!, rowBytes: 4 * MemoryLayout<Float>.size,
          bounds: CGRect(x: 48, y: 32, width: 1, height: 1), format: .RGBAf,
          colorSpace: space)
      }
      return pixels[0]
    }

    let legacy = edgeValue(light: 4, version: 1)
    let moderate = edgeValue(light: 2, version: 2)
    let bright = edgeValue(light: 4, version: 2)
    XCTAssertEqual(legacy, 0.18, accuracy: 0.001)
    XCTAssertGreaterThan(moderate, legacy + 0.005)
    XCTAssertGreaterThan(bright, moderate + 0.005)
  }

  func testSceneHighlightMaskRespondsAcrossBrightStopsAndShotExposure() throws {
    let kernel = try XCTUnwrap(FilmKernels.kernel("sceneHighlightMask"))
    let bounds = CGRect(x: 0, y: 0, width: 1, height: 1)
    let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
    let context = CIContext(options: [.workingColorSpace: space, .workingFormat: CIFormat.RGBAf])
    func mask(_ light: CGFloat, ev: Double = 0) throws -> Float {
      let source = CIImage(
        color: CIColor(red: light, green: light, blue: light, colorSpace: space)!
      ).cropped(to: bounds)
      let image = try XCTUnwrap(kernel.apply(extent: bounds, arguments: [source, ev]))
      var pixels = [Float](repeating: 0, count: 4)
      pixels.withUnsafeMutableBytes { bytes in
        context.render(
          image, toBitmap: bytes.baseAddress!, rowBytes: 4 * MemoryLayout<Float>.size,
          bounds: bounds, format: .RGBAf, colorSpace: space)
      }
      return pixels[0]
    }

    let dim = try mask(0.5)
    let first = try mask(1)
    let second = try mask(2)
    let third = try mask(4)
    XCTAssertLessThan(dim, 0.001)
    XCTAssertGreaterThan(first, dim)
    XCTAssertGreaterThan(second, first + 0.15)
    XCTAssertGreaterThan(third, second + 0.15)
    XCTAssertEqual(try mask(1, ev: 1), second, accuracy: 0.001)
  }

  func testSavedGradesKeepPreviousHalationUntilTextureUpgrade() throws {
    let legacy = try JSONDecoder().decode(PhotoEdits.self, from: Data("{}".utf8))
    XCTAssertEqual(legacy.halationVersion, 1)
    XCTAssertEqual(PhotoEdits().halationVersion, 2)
    XCTAssertEqual(legacy.resetting(.texture, isRAW: false).halationVersion, 2)

    let destination = PhotoEdits.defaults(forRAW: false)
    let transferred = PhotoEdits.transferring(legacy, panel: .texture, onto: destination)
    XCTAssertEqual(transferred.halationVersion, 1)
    let saved = try JSONDecoder().decode(
      PhotoEdits.self, from: JSONEncoder().encode(PhotoEdits()))
    XCTAssertEqual(saved.halationVersion, 2)
  }
}

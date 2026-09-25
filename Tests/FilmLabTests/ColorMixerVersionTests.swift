import CoreImage
import XCTest

@testable import FilmLab

final class ColorMixerVersionTests: XCTestCase {
  func testLegacyGradeKeepsOriginalMixerUntilUpgrade() throws {
    let legacy = try JSONDecoder().decode(PhotoEdits.self, from: Data("{}".utf8))
    XCTAssertEqual(legacy.mixerVersion, 1)
    XCTAssertEqual(PhotoEdits().mixerVersion, 2)

    let destination = PhotoEdits.defaults(forRAW: true)
    let transferred = PhotoEdits.transferring(legacy, panel: .color, onto: destination)
    XCTAssertEqual(transferred.mixerVersion, 1)
    XCTAssertEqual(transferred.resetting(.color, isRAW: true).mixerVersion, 1)
    XCTAssertEqual(legacy.resetting(.color, isRAW: false).mixerVersion, 1)
  }

  func testNewGradeRoundTripRetainsMixerVersion() throws {
    let saved = try JSONEncoder().encode(PhotoEdits.defaults(forRAW: false))
    let loaded = try JSONDecoder().decode(PhotoEdits.self, from: saved)
    XCTAssertEqual(loaded.mixerVersion, 2)
  }

  func testLegacyAndNewMixerRenderDiffer() throws {
    let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
    let context = CIContext(options: [
      .workingColorSpace: space,
      .workingFormat: CIFormat.RGBAf,
    ])
    let source = CIImage(
      color: CIColor(red: 0.8, green: 0.12, blue: 0.05, colorSpace: space)!
    ).cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
    var bands = Array(repeating: ColorMix(), count: 8)
    bands[0].hue = 30
    bands[0].saturation = 1
    func channels(_ image: CIImage) -> [Float] {
      var pixel = [Float](repeating: 0, count: 4)
      pixel.withUnsafeMutableBytes { bytes in
        context.render(
          image, toBitmap: bytes.baseAddress!, rowBytes: 16,
          bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
          format: .RGBAf, colorSpace: space)
      }
      return Array(pixel.prefix(3))
    }
    let legacy = channels(ColorMixer.apply(to: source, adjustments: bands, version: 1))
    let newer = channels(ColorMixer.apply(to: source, adjustments: bands, version: 2))
    XCTAssertGreaterThan(zip(legacy, newer).map { abs($0 - $1) }.max() ?? 0, 0.001)
  }
}

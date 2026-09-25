import CoreImage
import XCTest

@testable import FilmLab

final class ThumbnailSpatialEffectsTests: XCTestCase {
  func testScaledHalationMatchesFullResolutionBetterThanUnscaledThumbnail() throws {
    let extent = CGRect(x: 0, y: 0, width: 2048, height: 512)
    let black = CIImage(color: CIColor(red: 0.02, green: 0.02, blue: 0.02))
      .cropped(to: extent)
    let bright = CIImage(color: CIColor(red: 2, green: 2, blue: 2))
      .cropped(to: CGRect(x: 950, y: 0, width: 148, height: 512))
    let full = bright.composited(over: black)
    let thumbnailInput = full.transformed(by: CGAffineTransform(scaleX: 0.25, y: 0.25))
    let fullEffect = FilmEffects.apply(to: full, grain: 0, halation: 1)
    let scaledEffect = FilmEffects.apply(
      to: thumbnailInput, grain: 0, halation: 1, spatialScale: 0.25)
    let unscaledEffect = FilmEffects.apply(to: thumbnailInput, grain: 0, halation: 1)
    let colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
    let context = CIContext(options: [
      .workingColorSpace: colorSpace, .workingFormat: CIFormat.RGBAf,
    ])
    func sampled(_ image: CIImage, scale: CGFloat) -> [Float] {
      let reduced = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
      let bounds = CGRect(x: 0, y: 0, width: 256, height: 64)
      var pixels = [Float](repeating: 0, count: 256 * 64 * 4)
      pixels.withUnsafeMutableBytes { bytes in
        context.render(
          reduced, toBitmap: bytes.baseAddress!, rowBytes: 256 * 4 * MemoryLayout<Float>.size,
          bounds: bounds, format: .RGBAf, colorSpace: colorSpace)
      }
      return pixels
    }
    let reference = sampled(fullEffect, scale: 0.125)
    let scaled = sampled(scaledEffect, scale: 0.5)
    let unscaled = sampled(unscaledEffect, scale: 0.5)
    func error(_ candidate: [Float]) -> Double {
      let differences = zip(reference, candidate).map { abs($0 - $1) }
      return Double(differences.reduce(0, +)) / Double(differences.count)
    }
    XCTAssertLessThan(error(scaled), error(unscaled) * 0.75)
  }
}

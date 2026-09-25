import CoreImage
import Foundation
import XCTest

@testable import FilmLab

final class EditedThumbnailParityTests: XCTestCase {
  func testDetailedThumbnailMatchesFitPreviewDownsampling() async throws {
    let width = 960
    let height = 640
    var pixels = [UInt8](repeating: 255, count: width * height * 4)
    for y in 0..<height {
      for x in 0..<width {
        let offset = (y * width + x) * 4
        let value: UInt8 = ((x + y) % 3 == 0) ? 220 : 30
        pixels[offset] = value
        pixels[offset + 1] = value
        pixels[offset + 2] = value
      }
    }
    let workingSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
    let source = pixels.withUnsafeBytes { bytes in
      CIImage(
        bitmapData: Data(bytes), bytesPerRow: width * 4,
        size: CGSize(width: width, height: height), format: .RGBA8,
        colorSpace: workingSpace)
    }
    let renderedThumbnail = await EditedThumbnailRenderer.shared.render(source)
    let thumbnail = try XCTUnwrap(renderedThumbnail)
    let renderedPreview = await PreviewRenderer().render(
      PreviewRequest(
        image: source, scale: 320 / CGFloat(width), sourceURL: nil,
        originalImage: nil, showGamutWarning: false))
    let preview = try XCTUnwrap(renderedPreview?.image)
    XCTAssertEqual(thumbnail.width, preview.width)
    XCTAssertEqual(thumbnail.height, preview.height)
    let context = CIContext(options: [
      .workingColorSpace: workingSpace, .workingFormat: CIFormat.RGBAf,
    ])
    let displaySpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
    func channels(_ image: CGImage) -> [UInt8] {
      var result = [UInt8](repeating: 0, count: image.width * image.height * 4)
      result.withUnsafeMutableBytes { bytes in
        context.render(
          CIImage(cgImage: image), toBitmap: bytes.baseAddress!,
          rowBytes: image.width * 4,
          bounds: CGRect(x: 0, y: 0, width: image.width, height: image.height),
          format: .RGBA8, colorSpace: displaySpace)
      }
      return result
    }
    let thumbnailPixels = channels(thumbnail)
    let previewPixels = channels(preview)
    let meanDifference =
      zip(thumbnailPixels, previewPixels)
      .map { abs(Int($0) - Int($1)) }
      .reduce(0, +) / thumbnailPixels.count
    XCTAssertLessThanOrEqual(meanDifference, 1)
  }
}

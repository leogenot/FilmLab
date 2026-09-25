import CoreGraphics
import Foundation
import XCTest

@testable import FilmLab

@MainActor
final class ReferencePreviewTests: XCTestCase {
  func testRAWAndJPEGCanRenderAsIndependentReferences() async throws {
    let environment = ProcessInfo.processInfo.environment
    guard let rawPath = environment["FILMLAB_TEST_RAW"],
      let jpegPath = environment["FILMLAB_TEST_JPEG"]
    else { throw XCTSkip("Provide disposable RAW and JPEG paths") }

    for path in [rawPath, jpegPath] {
      let rendered = await PhotoEditor.renderedReference(
        for: URL(fileURLWithPath: path), displayP3: false)
      let reference = try XCTUnwrap(rendered)
      XCTAssertGreaterThan(max(reference.width, reference.height), 320)
      XCTAssertLessThanOrEqual(max(reference.width, reference.height), 1200)
      XCTAssertEqual(reference.colorSpace?.name, CGColorSpace.sRGB)
    }

    let renderedP3 = await PhotoEditor.renderedReference(
      for: URL(fileURLWithPath: jpegPath), displayP3: true)
    let p3Reference = try XCTUnwrap(renderedP3)
    XCTAssertEqual(p3Reference.colorSpace?.name, CGColorSpace.displayP3)
  }
}

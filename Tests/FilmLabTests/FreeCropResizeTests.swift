import CoreGraphics
import XCTest

@testable import FilmLab

final class FreeCropResizeTests: XCTestCase {
  func testCornerDragResizesOnlyTheDraggedEdges() {
    let crop = FreeCrop(centerX: 0.5, centerY: 0.5, width: 0.8, height: 0.8)
    let resized = crop.resized(corner: .topLeft, dx: 0.2, dy: 0.1)
    let bounds = resized.normalizedBounds
    XCTAssertEqual(bounds.minX, 0.3, accuracy: 0.0001)
    XCTAssertEqual(bounds.minY, 0.2, accuracy: 0.0001)
    XCTAssertEqual(bounds.maxX, 0.9, accuracy: 0.0001)
    XCTAssertEqual(bounds.maxY, 0.9, accuracy: 0.0001)
    XCTAssertEqual(crop.normalizedBounds.minX, 0.1, accuracy: 0.0001)
    XCTAssertEqual(FreeCropCorner.topLeft.point(in: bounds).x, bounds.minX)
    XCTAssertEqual(FreeCropCorner.bottomRight.point(in: bounds).y, bounds.maxY)
  }

  func testCornerDragClampsToImageAndMinimumSize() {
    let crop = FreeCrop(centerX: 0.5, centerY: 0.5, width: 0.8, height: 0.8)
    let smallest = crop.resized(corner: .bottomRight, dx: -2, dy: -2).normalizedBounds
    XCTAssertEqual(smallest.width, 0.1, accuracy: 0.0001)
    XCTAssertEqual(smallest.height, 0.1, accuracy: 0.0001)
    let largest = crop.resized(corner: .topRight, dx: 2, dy: -2).normalizedBounds
    XCTAssertEqual(largest.maxX, 1, accuracy: 0.0001)
    XCTAssertEqual(largest.minY, 0, accuracy: 0.0001)
    XCTAssertEqual(largest.minX, 0.1, accuracy: 0.0001)
    XCTAssertEqual(largest.maxY, 0.9, accuracy: 0.0001)
  }
}

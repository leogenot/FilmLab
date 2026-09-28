import XCTest

@testable import FilmLab

final class LocalCanvasMoveTests: XCTestCase {
  func testPaintedAreaMovesEveryStrokeWithoutChangingItsShape() {
    let area = RadialAdjustment(
      shape: 2,
      strokes: [
        BrushStroke(points: [BrushPoint(x: 0.2, y: 0.3), BrushPoint(x: 0.4, y: 0.5)]),
        BrushStroke(points: [BrushPoint(x: 0.6, y: 0.7)], erasing: true),
      ])
    let moved = area.translated(dx: 0.2, dy: -0.1)
    XCTAssertEqual(moved.strokes[0].points[0].x, 0.4, accuracy: 0.0001)
    XCTAssertEqual(moved.strokes[0].points[0].y, 0.2, accuracy: 0.0001)
    XCTAssertEqual(moved.strokes[1].points[0].x, 0.8, accuracy: 0.0001)
    XCTAssertTrue(moved.strokes[1].erasing)
    XCTAssertEqual(
      moved.strokes[0].points[1].x - moved.strokes[0].points[0].x, 0.2, accuracy: 0.0001)
    XCTAssertEqual(area.strokes[0].points[0].x, 0.2)
  }

  func testPaintedAreaClampsAsAGroupAtSourceEdges() {
    let area = RadialAdjustment(
      shape: 2,
      strokes: [BrushStroke(points: [BrushPoint(x: 0.2, y: 0.2), BrushPoint(x: 0.9, y: 0.8)])])
    let moved = area.translated(dx: 0.5, dy: -0.5)
    XCTAssertEqual(moved.strokes[0].points[0].x, 0.3, accuracy: 0.0001)
    XCTAssertEqual(moved.strokes[0].points[1].x, 1, accuracy: 0.0001)
    XCTAssertEqual(moved.strokes[0].points[0].y, 0, accuracy: 0.0001)
    XCTAssertEqual(moved.strokes[0].points[1].y, 0.6, accuracy: 0.0001)
  }
}

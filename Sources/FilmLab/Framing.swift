import CoreImage

enum Framing {
  static func apply(
    to image: CIImage, quarterTurns: Int, straightenDegrees: Double,
    aspect: Int, offsetX: Double, offsetY: Double
  ) -> CIImage {
    let turns = ((quarterTurns % 4) + 4) % 4
    var result = image
    if turns != 0 {
      result = result.transformed(by: CGAffineTransform(rotationAngle: CGFloat(turns) * .pi / 2))
      result = result.transformed(
        by: CGAffineTransform(translationX: -result.extent.minX, y: -result.extent.minY))
    }

    let degrees = min(max(straightenDegrees, -15), 15)
    if abs(degrees) > 0.001 {
      let original = result.extent
      let angle = CGFloat(degrees) * .pi / 180
      let center = CGPoint(x: original.midX, y: original.midY)
      let rotation =
        CGAffineTransform(translationX: center.x, y: center.y)
        .rotated(by: angle)
        .translatedBy(x: -center.x, y: -center.y)
      result = result.transformed(by: rotation)

      // Keep the largest centered rectangle at the original aspect ratio whose
      // four corners remain inside the rotated source rectangle.
      let cosine = abs(cos(angle))
      let sine = abs(sin(angle))
      let ratio = original.width / original.height
      let safeHeight = min(
        original.width / (ratio * cosine + sine),
        original.height / (ratio * sine + cosine))
      let safeWidth = safeHeight * ratio
      let safe = CGRect(
        x: result.extent.midX - safeWidth / 2,
        y: result.extent.midY - safeHeight / 2,
        width: safeWidth, height: safeHeight)
      result = result.cropped(to: safe)
    }

    let extent = result.extent
    let ratio: CGFloat? =
      switch aspect {
      case 1: 1
      case 2: 4.0 / 5.0
      case 3: 3.0 / 2.0
      case 4: 16.0 / 9.0
      default: nil
      }
    guard let ratio, extent.width > 0, extent.height > 0 else { return result }
    let width = min(extent.width, floor(extent.height * ratio))
    let height = min(extent.height, floor(extent.width / ratio))
    let x = extent.minX + (extent.width - width) * CGFloat(min(max(offsetX, -1), 1) + 1) / 2
    let y = extent.minY + (extent.height - height) * CGFloat(min(max(offsetY, -1), 1) + 1) / 2
    return result.cropped(to: CGRect(x: floor(x), y: floor(y), width: width, height: height))
  }
}

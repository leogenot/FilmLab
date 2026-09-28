import CoreImage

enum Framing {
  /// Moves a fixed-ratio crop in response to dragging the visible image.
  static func fixedCropOffsets(
    aspect: Int, sourceExtent: CGRect, quarterTurns: Int,
    dragX: Double, dragY: Double, originalX: Double, originalY: Double
  ) -> CGPoint {
    guard sourceExtent.width > 0, sourceExtent.height > 0,
      dragX.isFinite, dragY.isFinite
    else { return CGPoint(x: originalX, y: originalY) }
    let target: Double =
      switch aspect {
      case 1: 1
      case 2: 4.0 / 5.0
      case 3: 3.0 / 2.0
      case 4: 16.0 / 9.0
      case 6: 2.0 / 3.0
      case 7: 9.0 / 16.0
      default: 0
      }
    guard target > 0 else { return CGPoint(x: originalX, y: originalY) }
    let turns = ((quarterTurns % 4) + 4) % 4
    let sourceRatio = Double(
      turns % 2 == 0
        ? sourceExtent.width / sourceExtent.height
        : sourceExtent.height / sourceExtent.width)
    if sourceRatio > target + 0.0001 {
      let delta = -2 * dragX * target / (sourceRatio - target)
      return CGPoint(x: min(max(originalX + delta, -1), 1), y: originalY)
    }
    if sourceRatio < target - 0.0001 {
      let delta = 2 * dragY * sourceRatio / (target - sourceRatio)
      return CGPoint(x: originalX, y: min(max(originalY + delta, -1), 1))
    }
    return CGPoint(x: originalX, y: originalY)
  }

  /// Maps a point in the fitted, framed canvas (top-left origin) back to the source.
  static func sourceLocation(
    displayX: Double, displayY: Double, sourceExtent: CGRect,
    quarterTurns: Int, straightenDegrees: Double,
    aspect: Int, offsetX: Double, offsetY: Double, freeCrop: FreeCrop = FreeCrop(),
    flipHorizontal: Bool = false, flipVertical: Bool = false
  ) -> CGPoint? {
    guard (0...1).contains(displayX), (0...1).contains(displayY),
      sourceExtent.width > 0, sourceExtent.height > 0
    else { return nil }
    let turns = ((quarterTurns % 4) + 4) % 4
    var extent = sourceExtent
    var quarter = CGAffineTransform.identity
    if turns != 0 {
      let rotation = CGAffineTransform(rotationAngle: CGFloat(turns) * .pi / 2)
      let rotated = extent.applying(rotation)
      quarter = rotation.concatenating(
        CGAffineTransform(translationX: -rotated.minX, y: -rotated.minY))
      extent = extent.applying(quarter)
    }

    var flip = CGAffineTransform.identity
    if flipHorizontal || flipVertical {
      flip = CGAffineTransform(
        a: flipHorizontal ? -1 : 1, b: 0, c: 0, d: flipVertical ? -1 : 1,
        tx: flipHorizontal ? extent.minX + extent.maxX : 0,
        ty: flipVertical ? extent.minY + extent.maxY : 0)
    }

    let degrees = min(max(straightenDegrees, -15), 15)
    var straight = CGAffineTransform.identity
    if abs(degrees) > 0.001 {
      let original = extent
      let angle = CGFloat(degrees) * .pi / 180
      let center = CGPoint(x: original.midX, y: original.midY)
      straight = CGAffineTransform(translationX: center.x, y: center.y)
        .rotated(by: angle)
        .translatedBy(x: -center.x, y: -center.y)
      let rotated = extent.applying(straight)
      let cosine = abs(cos(angle))
      let sine = abs(sin(angle))
      let ratio = original.width / original.height
      let safeHeight = min(
        original.width / (ratio * cosine + sine),
        original.height / (ratio * sine + cosine))
      let safeWidth = safeHeight * ratio
      extent = CGRect(
        x: rotated.midX - safeWidth / 2, y: rotated.midY - safeHeight / 2,
        width: safeWidth, height: safeHeight)
    }

    let ratio: CGFloat? =
      switch aspect {
      case 1: 1
      case 2: 4.0 / 5.0
      case 3: 3.0 / 2.0
      case 4: 16.0 / 9.0
      case 6: 2.0 / 3.0
      case 7: 9.0 / 16.0
      default: nil
      }
    if aspect == 5 {
      extent = freeCrop.imageRect(in: extent)
    } else if let ratio {
      let width = min(extent.width, floor(extent.height * ratio))
      let height = min(extent.height, floor(extent.width / ratio))
      let x = extent.minX + (extent.width - width) * CGFloat(min(max(offsetX, -1), 1) + 1) / 2
      let y = extent.minY + (extent.height - height) * CGFloat(min(max(offsetY, -1), 1) + 1) / 2
      extent = CGRect(x: floor(x), y: floor(y), width: width, height: height)
    }
    guard extent.width > 0, extent.height > 0 else { return nil }
    let displayed = CGPoint(
      x: extent.minX + extent.width * displayX,
      y: extent.maxY - extent.height * displayY)
    let sourcePoint = displayed.applying(straight.inverted()).applying(flip.inverted())
      .applying(quarter.inverted())
    let x = (sourcePoint.x - sourceExtent.minX) / sourceExtent.width
    let y = (sourcePoint.y - sourceExtent.minY) / sourceExtent.height
    guard x.isFinite, y.isFinite, x >= -0.001, x <= 1.001, y >= -0.001, y <= 1.001 else {
      return nil
    }
    return CGPoint(x: min(max(x, 0), 1), y: min(max(y, 0), 1))
  }

  /// Maps a source-normalized point into the fitted, framed canvas (top-left origin).
  /// Points outside the current crop remain outside 0...1 so handles can be hidden.
  static func displayLocation(
    sourceX: Double, sourceY: Double, sourceExtent: CGRect,
    quarterTurns: Int, straightenDegrees: Double,
    aspect: Int, offsetX: Double, offsetY: Double, freeCrop: FreeCrop = FreeCrop(),
    flipHorizontal: Bool = false, flipVertical: Bool = false
  ) -> CGPoint? {
    guard sourceX.isFinite, sourceY.isFinite, sourceExtent.width > 0, sourceExtent.height > 0
    else { return nil }
    let turns = ((quarterTurns % 4) + 4) % 4
    var extent = sourceExtent
    var quarter = CGAffineTransform.identity
    if turns != 0 {
      let rotation = CGAffineTransform(rotationAngle: CGFloat(turns) * .pi / 2)
      let rotated = extent.applying(rotation)
      quarter = rotation.concatenating(
        CGAffineTransform(translationX: -rotated.minX, y: -rotated.minY))
      extent = extent.applying(quarter)
    }
    var flip = CGAffineTransform.identity
    if flipHorizontal || flipVertical {
      flip = CGAffineTransform(
        a: flipHorizontal ? -1 : 1, b: 0, c: 0, d: flipVertical ? -1 : 1,
        tx: flipHorizontal ? extent.minX + extent.maxX : 0,
        ty: flipVertical ? extent.minY + extent.maxY : 0)
    }
    let degrees = min(max(straightenDegrees, -15), 15)
    var straight = CGAffineTransform.identity
    if abs(degrees) > 0.001 {
      let original = extent
      let angle = CGFloat(degrees) * .pi / 180
      let center = CGPoint(x: original.midX, y: original.midY)
      straight = CGAffineTransform(translationX: center.x, y: center.y)
        .rotated(by: angle)
        .translatedBy(x: -center.x, y: -center.y)
      let rotated = extent.applying(straight)
      let cosine = abs(cos(angle))
      let sine = abs(sin(angle))
      let ratio = original.width / original.height
      let safeHeight = min(
        original.width / (ratio * cosine + sine),
        original.height / (ratio * sine + cosine))
      let safeWidth = safeHeight * ratio
      extent = CGRect(
        x: rotated.midX - safeWidth / 2, y: rotated.midY - safeHeight / 2,
        width: safeWidth, height: safeHeight)
    }
    let ratio: CGFloat? =
      switch aspect {
      case 1: 1
      case 2: 4.0 / 5.0
      case 3: 3.0 / 2.0
      case 4: 16.0 / 9.0
      case 6: 2.0 / 3.0
      case 7: 9.0 / 16.0
      default: nil
      }
    if aspect == 5 {
      extent = freeCrop.imageRect(in: extent)
    } else if let ratio {
      let width = min(extent.width, floor(extent.height * ratio))
      let height = min(extent.height, floor(extent.width / ratio))
      let x = extent.minX + (extent.width - width) * CGFloat(min(max(offsetX, -1), 1) + 1) / 2
      let y = extent.minY + (extent.height - height) * CGFloat(min(max(offsetY, -1), 1) + 1) / 2
      extent = CGRect(x: floor(x), y: floor(y), width: width, height: height)
    }
    guard extent.width > 0, extent.height > 0 else { return nil }
    let point = CGPoint(
      x: sourceExtent.minX + sourceExtent.width * CGFloat(sourceX),
      y: sourceExtent.minY + sourceExtent.height * CGFloat(sourceY)
    ).applying(quarter).applying(flip).applying(straight)
    return CGPoint(
      x: (point.x - extent.minX) / extent.width,
      y: (extent.maxY - point.y) / extent.height)
  }

  static func apply(
    to image: CIImage, quarterTurns: Int, straightenDegrees: Double,
    aspect: Int, offsetX: Double, offsetY: Double, freeCrop: FreeCrop = FreeCrop(),
    flipHorizontal: Bool = false, flipVertical: Bool = false
  ) -> CIImage {
    let turns = ((quarterTurns % 4) + 4) % 4
    var result = image
    if turns != 0 {
      result = result.transformed(by: CGAffineTransform(rotationAngle: CGFloat(turns) * .pi / 2))
      result = result.transformed(
        by: CGAffineTransform(translationX: -result.extent.minX, y: -result.extent.minY))
    }

    if flipHorizontal || flipVertical {
      let extent = result.extent
      result = result.transformed(
        by: CGAffineTransform(
          a: flipHorizontal ? -1 : 1, b: 0, c: 0, d: flipVertical ? -1 : 1,
          tx: flipHorizontal ? extent.minX + extent.maxX : 0,
          ty: flipVertical ? extent.minY + extent.maxY : 0))
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
      case 6: 2.0 / 3.0
      case 7: 9.0 / 16.0
      default: nil
      }
    guard extent.width > 0, extent.height > 0 else { return result }
    if aspect == 5 { return result.cropped(to: freeCrop.imageRect(in: extent)) }
    guard let ratio else { return result }
    let width = min(extent.width, floor(extent.height * ratio))
    let height = min(extent.height, floor(extent.width / ratio))
    let x = extent.minX + (extent.width - width) * CGFloat(min(max(offsetX, -1), 1) + 1) / 2
    let y = extent.minY + (extent.height - height) * CGFloat(min(max(offsetY, -1), 1) + 1) / 2
    return result.cropped(to: CGRect(x: floor(x), y: floor(y), width: width, height: height))
  }
}

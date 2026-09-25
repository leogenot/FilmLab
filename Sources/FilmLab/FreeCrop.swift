import CoreGraphics

/// A freeform crop in top-left normalized coordinates after rotation and straighten.
struct FreeCrop: Codable, Equatable {
  var centerX = 0.5
  var centerY = 0.5
  var width = 0.8
  var height = 0.8

  var normalizedBounds: CGRect {
    let w = min(max(width, 0.1), 1)
    let h = min(max(height, 0.1), 1)
    let x = min(max(centerX, w / 2), 1 - w / 2) - w / 2
    let y = min(max(centerY, h / 2), 1 - h / 2) - h / 2
    return CGRect(x: x, y: y, width: w, height: h)
  }

  func imageRect(in extent: CGRect) -> CGRect {
    let bounds = normalizedBounds
    let width = max(1, floor(extent.width * bounds.width))
    let height = max(1, floor(extent.height * bounds.height))
    let x = min(extent.maxX - width, floor(extent.minX + extent.width * bounds.minX))
    let y = min(extent.maxY - height, floor(extent.maxY - extent.height * bounds.maxY))
    return CGRect(x: x, y: y, width: width, height: height)
  }
}

enum FreeCropCorner: CaseIterable {
  case topLeft
  case topRight
  case bottomLeft
  case bottomRight

  func point(in bounds: CGRect) -> CGPoint {
    switch self {
    case .topLeft: CGPoint(x: bounds.minX, y: bounds.minY)
    case .topRight: CGPoint(x: bounds.maxX, y: bounds.minY)
    case .bottomLeft: CGPoint(x: bounds.minX, y: bounds.maxY)
    case .bottomRight: CGPoint(x: bounds.maxX, y: bounds.maxY)
    }
  }
}

extension FreeCrop {
  func resized(corner: FreeCropCorner, dx: Double, dy: Double) -> FreeCrop {
    let bounds = normalizedBounds
    var left = Double(bounds.minX)
    var right = Double(bounds.maxX)
    var top = Double(bounds.minY)
    var bottom = Double(bounds.maxY)
    switch corner {
    case .topLeft:
      left = min(max(left + dx, 0), right - 0.1)
      top = min(max(top + dy, 0), bottom - 0.1)
    case .topRight:
      right = max(min(right + dx, 1), left + 0.1)
      top = min(max(top + dy, 0), bottom - 0.1)
    case .bottomLeft:
      left = min(max(left + dx, 0), right - 0.1)
      bottom = max(min(bottom + dy, 1), top + 0.1)
    case .bottomRight:
      right = max(min(right + dx, 1), left + 0.1)
      bottom = max(min(bottom + dy, 1), top + 0.1)
    }
    return FreeCrop(
      centerX: (left + right) / 2, centerY: (top + bottom) / 2,
      width: right - left, height: bottom - top)
  }
}

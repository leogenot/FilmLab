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

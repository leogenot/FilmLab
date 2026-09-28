import CoreGraphics

/// Chooses a stable, padded source-pixel region around the visible 100% viewport.
enum ZoomTile {
  static func rect(for viewport: CGRect, canvas: CGSize) -> CGRect {
    let width = max(1, ceil(canvas.width))
    let height = max(1, ceil(canvas.height))
    let visible = viewport.intersection(CGRect(x: 0, y: 0, width: width, height: height))
    let focus = visible.isNull ? CGRect(x: 0, y: 0, width: 1, height: 1) : visible
    let left = max(0, floor((focus.minX - 256) / 512) * 512)
    let top = max(0, floor((focus.minY - 256) / 512) * 512)
    let right = min(width, ceil((focus.maxX + 256) / 512) * 512)
    let bottom = min(height, ceil((focus.maxY + 256) / 512) * 512)
    return CGRect(x: left, y: top, width: right - left, height: bottom - top)
  }
}

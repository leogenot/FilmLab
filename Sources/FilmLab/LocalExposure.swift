import CoreImage
import CoreImage.CIFilterBuiltins

/// A soft, elliptical light adjustment in normalized source coordinates.
enum LocalExposure {
  static func mask(
    for image: CIImage, centerX: Double, centerY: Double,
    radius: Double, feather: Double, inverted: Bool = false,
    shape: Int = 0, angle: Double = 90
  ) -> CIImage? {
    guard image.extent.width > 0, image.extent.height > 0 else { return nil }
    let extent = image.extent
    let x = min(max(centerX, 0), 1)
    let y = min(max(centerY, 0), 1)
    let outer = min(max(radius, 0.02), 1)
    if shape == 1 {
      let radians = min(max(angle, -180), 180) * .pi / 180
      let distance = min(extent.width, extent.height) * outer / 2
      let middle = CGPoint(
        x: extent.minX + extent.width * x, y: extent.minY + extent.height * y)
      let dx = cos(radians) * distance
      let dy = sin(radians) * distance
      let gradient = CIFilter.smoothLinearGradient()
      gradient.point0 = CGPoint(x: middle.x + dx, y: middle.y + dy)
      gradient.point1 = CGPoint(x: middle.x - dx, y: middle.y - dy)
      gradient.color0 = CIColor(red: 0, green: 0, blue: 0)
      gradient.color1 = CIColor(red: 1, green: 1, blue: 1)
      guard let mask = gradient.outputImage?.cropped(to: extent) else { return nil }
      return inverted ? mask.applyingFilter("CIColorInvert").cropped(to: extent) : mask
    }
    let inner = outer * (1 - min(max(feather, 0.01), 1))
    let gradient = CIFilter.radialGradient()
    gradient.center = CGPoint.zero
    gradient.radius0 = Float(inner)
    gradient.radius1 = Float(outer)
    gradient.color0 = CIColor(red: 1, green: 1, blue: 1)
    gradient.color1 = CIColor(red: 0, green: 0, blue: 0)
    guard let unitMask = gradient.outputImage else { return nil }
    let mask = unitMask.transformed(
      by: CGAffineTransform(
        a: extent.width, b: 0, c: 0, d: extent.height,
        tx: extent.minX + extent.width * x, ty: extent.minY + extent.height * y)
    ).cropped(to: extent)
    return inverted ? mask.applyingFilter("CIColorInvert").cropped(to: extent) : mask
  }

  static func apply(
    to image: CIImage, ev: Double, centerX: Double, centerY: Double,
    radius: Double, feather: Double, inverted: Bool = false,
    shape: Int = 0, angle: Double = 90
  ) -> CIImage {
    guard abs(ev) > 0.001, image.extent.width > 0, image.extent.height > 0 else {
      return image
    }
    guard
      let mask = mask(
        for: image, centerX: centerX, centerY: centerY, radius: radius, feather: feather,
        inverted: inverted, shape: shape, angle: angle)
    else { return image }
    let lit = image.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: ev])
    return lit.applyingFilter(
      "CIBlendWithMask",
      parameters: [kCIInputBackgroundImageKey: image, kCIInputMaskImageKey: mask]
    ).cropped(to: image.extent)
  }
}

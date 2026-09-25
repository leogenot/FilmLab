import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// A soft, elliptical light adjustment in normalized source coordinates.
enum LocalExposure {
  static func mask(
    for image: CIImage, centerX: Double, centerY: Double,
    radius: Double, feather: Double, inverted: Bool = false,
    shape: Int = 0, angle: Double = 90,
    brushSize: Double = 0.03, strokes: [BrushStroke] = [],
    toneRangeEnabled: Bool = false, toneCenter: Double = 0,
    toneWidth: Double = 4, toneFeather: Double = 1,
    hueRangeEnabled: Bool = false, hueCenter: Double = 210,
    hueWidth: Double = 45, hueFeather: Double = 20
  ) -> CIImage? {
    guard image.extent.width > 0, image.extent.height > 0 else { return nil }
    let extent = image.extent
    let x = min(max(centerX, 0), 1)
    let y = min(max(centerY, 0), 1)
    let outer = min(max(radius, 0.02), 1)
    if shape == 2 {
      guard
        let mask = paintedMask(
          extent: extent, brushSize: brushSize, feather: feather, strokes: strokes)
      else { return nil }
      let geometric = inverted ? mask.applyingFilter("CIColorInvert").cropped(to: extent) : mask
      return rangedMask(
        geometric, source: image, enabled: toneRangeEnabled,
        center: toneCenter, width: toneWidth, feather: toneFeather,
        hueEnabled: hueRangeEnabled, hueCenter: hueCenter,
        hueWidth: hueWidth, hueFeather: hueFeather)
    }
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
      let geometric = inverted ? mask.applyingFilter("CIColorInvert").cropped(to: extent) : mask
      return rangedMask(
        geometric, source: image, enabled: toneRangeEnabled,
        center: toneCenter, width: toneWidth, feather: toneFeather,
        hueEnabled: hueRangeEnabled, hueCenter: hueCenter,
        hueWidth: hueWidth, hueFeather: hueFeather)
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
    let geometric = inverted ? mask.applyingFilter("CIColorInvert").cropped(to: extent) : mask
    return rangedMask(
      geometric, source: image, enabled: toneRangeEnabled,
      center: toneCenter, width: toneWidth, feather: toneFeather,
      hueEnabled: hueRangeEnabled, hueCenter: hueCenter,
      hueWidth: hueWidth, hueFeather: hueFeather)
  }

  private static func rangedMask(
    _ geometry: CIImage, source: CIImage, enabled: Bool,
    center: Double, width: Double, feather: Double,
    hueEnabled: Bool, hueCenter: Double, hueWidth: Double, hueFeather: Double
  ) -> CIImage? {
    var result = geometry
    if enabled {
      guard let kernel = FilmKernels.kernel("localLuminanceMask"),
        let tone = kernel.apply(
          extent: source.extent, arguments: [source, center, width, feather])
      else { return nil }
      result = result.applyingFilter(
        "CIMultiplyBlendMode", parameters: [kCIInputBackgroundImageKey: tone]
      ).cropped(to: source.extent)
    }
    if hueEnabled {
      guard let kernel = FilmKernels.kernel("localHueMask"),
        let hue = kernel.apply(
          extent: source.extent, arguments: [source, hueCenter, hueWidth, hueFeather])
      else { return nil }
      result = result.applyingFilter(
        "CIMultiplyBlendMode", parameters: [kCIInputBackgroundImageKey: hue]
      ).cropped(to: source.extent)
    }
    return result
  }

  private static func paintedMask(
    extent: CGRect, brushSize: Double, feather: Double, strokes: [BrushStroke]
  ) -> CIImage? {
    let scale = min(1, 4096 / max(extent.width, extent.height))
    let width = max(1, Int(ceil(extent.width * scale)))
    let height = max(1, Int(ceil(extent.height * scale)))
    var pixels = [UInt8](repeating: 0, count: width * height)
    let bitmap = pixels.withUnsafeMutableBytes { bytes -> CGImage? in
      guard
        let context = CGContext(
          data: bytes.baseAddress, width: width, height: height,
          bitsPerComponent: 8, bytesPerRow: width,
          space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
      else { return nil }
      context.setStrokeColor(gray: 1, alpha: 1)
      context.setFillColor(gray: 1, alpha: 1)
      context.setLineCap(.round)
      context.setLineJoin(.round)
      for stroke in strokes where !stroke.points.isEmpty {
        context.setStrokeColor(gray: stroke.erasing ? 0 : 1, alpha: 1)
        context.setFillColor(gray: stroke.erasing ? 0 : 1, alpha: 1)
        let diameter = min(max(stroke.size, 0.003), 0.15) * Double(min(width, height))
        context.setLineWidth(diameter)
        let points = stroke.points.map {
          CGPoint(
            x: min(max($0.x, 0), 1) * Double(width),
            y: min(max($0.y, 0), 1) * Double(height))
        }
        if points.count == 1 {
          context.fillEllipse(
            in: CGRect(
              x: points[0].x - diameter / 2, y: points[0].y - diameter / 2,
              width: diameter, height: diameter))
        } else {
          context.beginPath()
          context.move(to: points[0])
          for point in points.dropFirst() { context.addLine(to: point) }
          context.strokePath()
        }
      }
      return context.makeImage()
    }
    guard let bitmap else { return nil }
    let base = CIImage(cgImage: bitmap)
    let largestStrokeSize = strokes.map(\.size).max() ?? brushSize
    let softness =
      min(max(feather, 0), 1) * min(max(largestStrokeSize, 0.003), 0.15)
      * Double(min(width, height)) * 0.35
    let softened =
      softness > 0.5
      ? base.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: softness])
      : base
    let transformed = softened.transformed(
      by: CGAffineTransform(
        a: extent.width / Double(width), b: 0,
        c: 0, d: extent.height / Double(height),
        tx: extent.minX, ty: extent.minY))
    return transformed.cropped(to: extent)
  }

  static func apply(
    to image: CIImage, ev: Double, warmth: Double = 0, tint: Double = 0,
    centerX: Double, centerY: Double,
    radius: Double, feather: Double, inverted: Bool = false,
    shape: Int = 0, angle: Double = 90,
    brushSize: Double = 0.03, strokes: [BrushStroke] = [],
    toneRangeEnabled: Bool = false, toneCenter: Double = 0,
    toneWidth: Double = 4, toneFeather: Double = 1,
    hueRangeEnabled: Bool = false, hueCenter: Double = 210,
    hueWidth: Double = 45, hueFeather: Double = 20
  ) -> CIImage {
    guard abs(ev) > 0.001 || abs(warmth) > 0.001 || abs(tint) > 0.001,
      image.extent.width > 0, image.extent.height > 0
    else {
      return image
    }
    guard
      let mask = mask(
        for: image, centerX: centerX, centerY: centerY, radius: radius, feather: feather,
        inverted: inverted, shape: shape, angle: angle,
        brushSize: brushSize, strokes: strokes,
        toneRangeEnabled: toneRangeEnabled, toneCenter: toneCenter,
        toneWidth: toneWidth, toneFeather: toneFeather,
        hueRangeEnabled: hueRangeEnabled, hueCenter: hueCenter,
        hueWidth: hueWidth, hueFeather: hueFeather)
    else { return image }
    var adjusted = image
    if abs(ev) > 0.001 {
      adjusted = adjusted.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: ev])
    }
    if abs(warmth) > 0.001 || abs(tint) > 0.001 {
      let balance = CIFilter.temperatureAndTint()
      balance.inputImage = adjusted
      balance.neutral = CIVector(x: 6500, y: 0)
      balance.targetNeutral = CIVector(x: 6500 - warmth * 1000, y: tint * 100)
      guard let balanced = balance.outputImage else { return image }
      adjusted = balanced
    }
    return adjusted.applyingFilter(
      "CIBlendWithMask",
      parameters: [kCIInputBackgroundImageKey: image, kCIInputMaskImageKey: mask]
    ).cropped(to: image.extent)
  }
}

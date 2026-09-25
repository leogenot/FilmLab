import CoreImage
import Foundation

@main
struct LocalExposureProbe {
  static func main() {
    let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
    let context = CIContext(options: [
      .workingColorSpace: space, .workingFormat: CIFormat.RGBAf,
    ])
    let source = CIImage(color: CIColor(red: 0.18, green: 0.18, blue: 0.18, colorSpace: space)!)
      .cropped(to: CGRect(x: 0, y: 0, width: 101, height: 101))
    func channel(_ image: CIImage, _ x: Int, _ y: Int, _ component: Int = 0) -> Float {
      var pixel = [Float](repeating: 0, count: 4)
      pixel.withUnsafeMutableBytes { bytes in
        context.render(
          image, toBitmap: bytes.baseAddress!, rowBytes: 16,
          bounds: CGRect(x: x, y: y, width: 1, height: 1), format: .RGBAf,
          colorSpace: space)
      }
      return pixel[component]
    }
    func red(_ image: CIImage, _ x: Int, _ y: Int) -> Float {
      channel(image, x, y)
    }
    let mask = LocalExposure.mask(
      for: source, centerX: 0.8, centerY: 0.2, radius: 0.2, feather: 0.5)!
    precondition(red(mask, 80, 20) > 0.99, "Mask center is not white")
    precondition(red(mask, 20, 80) < 0.01, "Mask corner is not black")
    let linearMask = LocalExposure.mask(
      for: source, centerX: 0.5, centerY: 0.5, radius: 0.4,
      feather: 0.5, shape: 1, angle: 90)!
    precondition(red(linearMask, 50, 10) > 0.99, "Linear mask lower side is not white")
    precondition(red(linearMask, 50, 90) < 0.01, "Linear mask upper side is not black")
    precondition(abs(red(linearMask, 50, 50) - 0.5) < 0.03, "Linear mask center is not half")
    let linearBright = LocalExposure.apply(
      to: source, ev: 1, centerX: 0.5, centerY: 0.5, radius: 0.4,
      feather: 0.5, shape: 1, angle: 90)
    precondition(red(linearBright, 50, 10) > 0.35, "Linear light did not brighten lower side")
    precondition(
      abs(red(linearBright, 50, 90) - 0.18) < 0.002,
      "Linear light changed the upper side")
    let brush = BrushStroke(points: [
      BrushPoint(x: 0.2, y: 0.7), BrushPoint(x: 0.35, y: 0.7),
    ])
    let legacyStroke = try! JSONDecoder().decode(
      BrushStroke.self, from: Data(#"{"points":[{"x":0.2,"y":0.7}]}"#.utf8))
    precondition(legacyStroke.size == 0.03, "Earlier painted strokes did not decode")
    precondition(!legacyStroke.erasing, "Earlier painted strokes must remain additive")
    let painted = LocalExposure.mask(
      for: source, centerX: 0.5, centerY: 0.5, radius: 0.35,
      feather: 0.2, shape: 2, strokes: [brush])!
    precondition(red(painted, 20, 70) > 0.95, "Painted source location is not white")
    let resizedTool = LocalExposure.mask(
      for: source, centerX: 0.5, centerY: 0.5, radius: 0.35,
      feather: 0.2, shape: 2, brushSize: 0.12, strokes: [brush])!
    precondition(
      abs(red(resizedTool, 20, 73) - red(painted, 20, 73)) < 0.002,
      "Changing the brush tool resized an existing stroke")
    precondition(red(painted, 80, 20) < 0.01, "Painted mask spills into untouched area")
    let erased = LocalExposure.mask(
      for: source, centerX: 0.5, centerY: 0.5, radius: 0.35,
      feather: 0, shape: 2,
      strokes: [
        brush,
        BrushStroke(points: [BrushPoint(x: 0.2, y: 0.7)], size: 0.03, erasing: true),
      ])!
    precondition(red(erased, 20, 70) < 0.01, "Eraser did not clear the painted point")
    precondition(red(erased, 35, 70) > 0.95, "Eraser cleared the rest of the stroke")
    let brushBright = LocalExposure.apply(
      to: source, ev: 1, centerX: 0.5, centerY: 0.5, radius: 0.35,
      feather: 0.2, shape: 2, strokes: [brush])
    precondition(red(brushBright, 20, 70) > 0.34, "Painted light did not brighten stroke")
    precondition(
      abs(red(brushBright, 80, 20) - 0.18) < 0.002,
      "Painted light changed the untouched area")
    let oldArea = try! JSONDecoder().decode(
      RadialAdjustment.self,
      from: Data(
        #"{"exposure":1,"centerX":0.2,"centerY":0.7,"radius":0.3,"feather":0.4,"inverted":true}"#
          .utf8))
    precondition(
      oldArea.shape == 0 && oldArea.angle == 90 && oldArea.inverted
        && oldArea.warmth == 0 && oldArea.tint == 0 && !oldArea.toneRangeEnabled,
      "Older saved radial areas did not decode")
    var tonalPixels = [Float](repeating: 1, count: 3 * 4)
    for (index, luminance) in [Float(0.018), 0.18, 1.8].enumerated() {
      for channel in 0..<3 { tonalPixels[index * 4 + channel] = luminance }
    }
    let tonalSource = tonalPixels.withUnsafeBytes { bytes in
      CIImage(
        bitmapData: Data(bytes), bytesPerRow: 3 * 4 * MemoryLayout<Float>.size,
        size: CGSize(width: 3, height: 1), format: .RGBAf, colorSpace: space)
    }
    let tonalMask = LocalExposure.mask(
      for: tonalSource, centerX: 0.5, centerY: 0.5, radius: 1,
      feather: 0.01, toneRangeEnabled: true, toneCenter: 0,
      toneWidth: 1, toneFeather: 0.5)!
    precondition(red(tonalMask, 0, 0) < 0.01, "Tonal mask included deep shadow")
    precondition(red(tonalMask, 1, 0) > 0.99, "Tonal mask omitted middle gray")
    precondition(red(tonalMask, 2, 0) < 0.01, "Tonal mask included bright highlight")
    let tonalBright = LocalExposure.apply(
      to: tonalSource, ev: 1, centerX: 0.5, centerY: 0.5,
      radius: 1, feather: 0.01, toneRangeEnabled: true,
      toneCenter: 0, toneWidth: 1, toneFeather: 0.5)
    precondition(abs(red(tonalBright, 0, 0) - 0.018) < 0.002, "Deep shadow changed")
    precondition(red(tonalBright, 1, 0) > 0.35, "Middle gray did not brighten")
    precondition(abs(red(tonalBright, 2, 0) - 1.8) < 0.002, "Bright highlight changed")
    let unchanged = LocalExposure.apply(
      to: source, ev: 0, centerX: 0.5, centerY: 0.5, radius: 0.35, feather: 0.5)
    precondition(unchanged === source, "Zero EV should skip the local graph")
    let bright = LocalExposure.apply(
      to: source, ev: 1, centerX: 0.5, centerY: 0.5, radius: 0.35, feather: 0.5)
    precondition(red(bright, 50, 50) > 0.35, "Center did not gain a stop")
    precondition(abs(red(bright, 0, 0) - 0.18) < 0.002, "Corner changed")
    let moved = LocalExposure.apply(
      to: source, ev: -1, centerX: 0.8, centerY: 0.2, radius: 0.2, feather: 0.5)
    precondition(red(moved, 80, 20) < 0.1, "Moved center did not darken")
    precondition(abs(red(moved, 20, 80) - 0.18) < 0.002, "Moved mask spilled")
    let colorBalanced = LocalExposure.apply(
      to: source, ev: 0, warmth: 0.8, tint: -0.5,
      centerX: 0.5, centerY: 0.5, radius: 0.2, feather: 0.5)
    let centerChange = (0..<3).map {
      abs(channel(colorBalanced, 50, 50, $0) - channel(source, 50, 50, $0))
    }
    precondition(centerChange.max()! > 0.01, "Local color did not change the selected pixel")
    for component in 0..<3 {
      precondition(
        abs(channel(colorBalanced, 0, 0, component) - channel(source, 0, 0, component)) < 0.002,
        "Local color changed an unselected pixel")
    }
    let linearColor = LocalExposure.apply(
      to: source, ev: 0, warmth: 0.8, centerX: 0.5, centerY: 0.5,
      radius: 0.4, feather: 0.5, shape: 1, angle: 90)
    precondition(
      abs(red(linearColor, 50, 10) - 0.18) > 0.01
        && abs(red(linearColor, 50, 90) - 0.18) < 0.002,
      "Linear color did not follow its mask")
    let paintedColor = LocalExposure.apply(
      to: source, ev: 0, warmth: 0.8, centerX: 0.5, centerY: 0.5,
      radius: 0.35, feather: 0.2, shape: 2, strokes: [brush])
    precondition(
      abs(red(paintedColor, 20, 70) - 0.18) > 0.01
        && abs(red(paintedColor, 80, 20) - 0.18) < 0.002,
      "Painted color did not follow its mask")
    let inverted = LocalExposure.apply(
      to: source, ev: -1, centerX: 0.5, centerY: 0.5,
      radius: 0.25, feather: 0.5, inverted: true)
    precondition(abs(red(inverted, 50, 50) - 0.18) < 0.002, "Inversion changed the center")
    precondition(red(inverted, 0, 0) < 0.1, "Inversion did not darken the edge")
    let layered = LocalExposure.apply(
      to: bright, ev: -1, centerX: 0.5, centerY: 0.5,
      radius: 0.25, feather: 0.5, inverted: true)
    precondition(red(layered, 50, 50) > 0.35, "Second area erased first center")
    precondition(red(layered, 0, 0) < 0.1, "Second area did not affect edge")
    print("Local scene-light checks passed")
  }
}

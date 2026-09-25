import Foundation

/// Percentiles of sampled decoded linear RGB before FilmLab's input and film controls.
struct InputExposureRange: Sendable, Equatable {
  let lowEV: Double
  let medianEV: Double
  let highEV: Double
  let deepShadowFraction: Double
  let aboveWhiteFraction: Double

  static func make(from pixels: [Float], width: Int, height: Int) -> InputExposureRange? {
    guard width > 0, height > 0, pixels.count >= width * height * 4 else { return nil }
    let floor = 0.18 * exp2(-12.0)
    var stops = [Double]()
    var deepShadows = 0
    var aboveWhite = 0
    stops.reserveCapacity(width * height)
    for offset in stride(from: 0, to: width * height * 4, by: 4) {
      let red = pixels[offset]
      let green = pixels[offset + 1]
      let blue = pixels[offset + 2]
      let alpha = pixels[offset + 3]
      guard red.isFinite, green.isFinite, blue.isFinite, alpha >= 0.5 else { continue }
      let light = 0.2126 * Double(red) + 0.7152 * Double(green) + 0.0722 * Double(blue)
      if light < 1.0 / 256.0 { deepShadows += 1 }
      if light > 1.0 { aboveWhite += 1 }
      stops.append(min(16, max(-12, log2(max(light, floor) / 0.18))))
    }
    guard !stops.isEmpty else { return nil }
    stops.sort()
    func percentile(_ fraction: Double) -> Double {
      let position = fraction * Double(stops.count - 1)
      let lower = Int(position)
      let upper = min(lower + 1, stops.count - 1)
      return stops[lower] + (stops[upper] - stops[lower]) * (position - Double(lower))
    }
    return InputExposureRange(
      lowEV: percentile(0.01), medianEV: percentile(0.5), highEV: percentile(0.99),
      deepShadowFraction: Double(deepShadows) / Double(stops.count),
      aboveWhiteFraction: Double(aboveWhite) / Double(stops.count))
  }
}

import CoreImage
import Foundation

@main
struct TextureProbe {
  static func main() {
    let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
    let source = CIImage(color: CIColor(red: 0.18, green: 0.18, blue: 0.18, colorSpace: space)!)
      .cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))
    let preview = CIContext(options: [.workingColorSpace: space, .workingFormat: CIFormat.RGBAh])
    let export = CIContext(options: [.workingColorSpace: space, .workingFormat: CIFormat.RGBAf])

    func pixels(_ image: CIImage, context: CIContext) -> [Float] {
      var output = [Float](repeating: 0, count: 64 * 64 * 4)
      output.withUnsafeMutableBytes { bytes in
        context.render(
          image, toBitmap: bytes.baseAddress!, rowBytes: 64 * 16,
          bounds: CGRect(x: 0, y: 0, width: 64, height: 64),
          format: .RGBAf, colorSpace: space)
      }
      return output
    }

    let first = pixels(FilmEffects.apply(to: source, grain: 0.75, halation: 0), context: preview)
    let second = pixels(FilmEffects.apply(to: source, grain: 0.75, halation: 0), context: preview)
    let full = pixels(FilmEffects.apply(to: source, grain: 0.75, halation: 0), context: export)
    precondition(first == second, "Grain changed between identical preview renders")
    let values = stride(from: 0, to: first.count, by: 4).map { first[$0] }
    precondition(values.max()! - values.min()! > 0.01, "Grain lacks spatial variation")
    let difference = zip(first, full).map { abs($0 - $1) }.max()!
    precondition(difference < 0.002, "Preview and export grain disagree")
    let seededA = pixels(
      FilmEffects.apply(to: source, grain: 0.75, grainSeed: 17, halation: 0), context: export)
    let seededAgain = pixels(
      FilmEffects.apply(to: source, grain: 0.75, grainSeed: 17, halation: 0), context: preview)
    let seededB = pixels(
      FilmEffects.apply(to: source, grain: 0.75, grainSeed: 29, halation: 0), context: export)
    precondition(seededA != full && seededA != seededB, "Photo seeds repeat the same grain")
    precondition(
      zip(seededA, seededAgain).map { abs($0 - $1) }.max()! < 0.002,
      "Seeded grain differs between preview and export")
    let fine = pixels(
      FilmEffects.apply(to: source, grain: 0.75, grainSize: 0, halation: 0), context: export)
    func horizontalCorrelation(_ pixels: [Float], distance: Int) -> Double {
      var covariance = 0.0
      var variance = 0.0
      for y in 8..<56 {
        for x in 8..<(56 - distance) {
          let a = Double(pixels[(y * 64 + x) * 4] - 0.18)
          let b = Double(pixels[(y * 64 + x + distance) * 4] - 0.18)
          covariance += a * b
          variance += a * a
        }
      }
      return covariance / variance
    }
    let neighbor = horizontalCorrelation(full, distance: 1)
    let secondNeighbor = horizontalCorrelation(full, distance: 2)
    let oldNeighbor = horizontalCorrelation(fine, distance: 1)
    precondition(neighbor > 0.5 && secondNeighbor > 0.15)
    precondition(abs(oldNeighbor) < 0.15, "Legacy fine grain changed its spatial character")
    print(
      "Deterministic grain checks passed; adjacent correlations \(neighbor), \(secondNeighbor), legacy \(oldNeighbor); maximum working-format difference \(difference)"
    )

    let dark = CIImage(color: CIColor(red: 0.12, green: 0.12, blue: 0.12, colorSpace: space)!)
      .cropped(to: CGRect(x: 0, y: 0, width: 32, height: 64))
    let light = CIImage(color: CIColor(red: 0.7, green: 0.7, blue: 0.7, colorSpace: space)!)
      .cropped(to: CGRect(x: 32, y: 0, width: 32, height: 64))
    let edge = dark.composited(over: light)
    let detailed = FilmEffects.apply(to: edge, grain: 0, halation: 0, acutance: 1)
    let detailedPreview = pixels(detailed, context: preview)
    let detailedExport = pixels(detailed, context: export)
    func level(_ values: [Float], x: Int, y: Int = 32) -> Float {
      values[(y * 64 + x) * 4]
    }
    precondition(level(detailedExport, x: 31) < 0.12, "Acutance did not darken the near edge")
    precondition(level(detailedExport, x: 32) > 0.7, "Acutance did not brighten the near edge")
    precondition(abs(level(detailedExport, x: 8) - 0.12) < 0.001, "Acutance changed a flat shadow")
    precondition(
      abs(level(detailedExport, x: 55) - 0.7) < 0.001, "Acutance changed a flat highlight")
    let edgeDifference = zip(detailedPreview, detailedExport).map { abs($0 - $1) }.max()!
    precondition(edgeDifference < 0.002, "Preview and export acutance disagree")
    print("Edge-detail checks passed; maximum working-format difference \(edgeDifference)")
  }
}

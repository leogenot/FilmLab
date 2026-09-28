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

    let negativeKernel = FilmKernels.kernel("measuredNegative")!
    let negativeGrain = FilmKernels.kernel("applyNegativeGrain")!
    let positiveKernel = FilmKernels.kernel("portraPositive")!
    func negativeTexture(_ stock: Double, version: Double, grain: Double) -> [Float] {
      let negative = negativeKernel.apply(
        extent: source.extent, arguments: [source, 0.0, 0.0, stock])!
      let textured = negativeGrain.apply(
        extent: source.extent, arguments: [negative, grain, 1.0, 17.0, stock, version])!
      return pixels(textured, context: export)
    }
    let oldEktar = negativeTexture(2, version: 2, grain: 0.75)
    let newEktar = negativeTexture(2, version: 3, grain: 0.75)
    let plainEktar = negativeTexture(2, version: 3, grain: 0)
    func textureRMS(_ rendered: [Float], baseline: [Float]) -> Double {
      let changes = stride(from: 0, to: rendered.count, by: 4).map {
        Double(rendered[$0] - baseline[$0])
      }
      return sqrt(changes.map { $0 * $0 }.reduce(0, +) / Double(changes.count))
    }
    precondition(
      textureRMS(newEktar, baseline: plainEktar)
        < textureRMS(oldEktar, baseline: plainEktar) * 0.8,
      "New Ektar texture is not quieter")
    func textureNeighborCorrelation(_ rendered: [Float], baseline: [Float]) -> Double {
      var covariance = 0.0
      var variance = 0.0
      for y in 8..<56 {
        for x in 8..<55 {
          let index = (y * 64 + x) * 4
          let next = index + 4
          let currentDelta = Double(rendered[index] - baseline[index])
          let neighborDelta = Double(rendered[next] - baseline[next])
          covariance += currentDelta * neighborDelta
          variance += currentDelta * currentDelta
        }
      }
      return covariance / variance
    }
    precondition(
      textureNeighborCorrelation(newEktar, baseline: plainEktar)
        < textureNeighborCorrelation(oldEktar, baseline: plainEktar),
      "New Ektar texture is not spatially finer")
    precondition(
      negativeTexture(1, version: 2, grain: 0.75)
        == negativeTexture(1, version: 3, grain: 0.75),
      "Portra texture changed with Ektar revision")
    func developed(_ stock: Double, _ exposure: Double, _ grain: Double) -> CIImage {
      let negative = negativeKernel.apply(
        extent: source.extent, arguments: [source, exposure, 0.0, stock])!
      let textured = negativeGrain.apply(
        extent: source.extent, arguments: [negative, grain, 1.0, 17.0, stock, 2.0])!
      return positiveKernel.apply(
        extent: source.extent,
        arguments: [textured, source, exposure, 1.0, 0.0, 0.0, stock])!
    }
    func grainSpread(_ stock: Double, _ exposure: Double) -> Double {
      let baseline = pixels(developed(stock, exposure, 0), context: export)
      let grained = pixels(developed(stock, exposure, 0.75), context: export)
      let delta = stride(from: 0, to: grained.count, by: 4).map {
        Double(grained[$0] - baseline[$0])
      }
      return sqrt(delta.map { $0 * $0 }.reduce(0, +) / Double(delta.count))
    }
    for stock in [1.0, 2.0, 3.0, 4.0, 5.0] {
      let midtone = developed(stock, 0, 0.75)
      let baseline = pixels(developed(stock, 0, 0), context: export)
      let rendered = pixels(midtone, context: export)
      let previewPixels = pixels(midtone, context: preview)
      precondition(rendered == pixels(developed(stock, 0, 0.75), context: export))
      precondition(
        zip(rendered, previewPixels).map { abs($0 - $1) }.max()! < 0.002,
        "Density-stage grain differs between preview and export")
      precondition(
        zip(rendered, baseline).map { abs($0 - $1) }.max()! > 0.005,
        "Density-stage grain is not visible")
      if stock >= 4 {
        var channelDifference: Float = 0
        for index in stride(from: 0, to: rendered.count, by: 4) {
          let redGreen = abs(rendered[index] - rendered[index + 1])
          let greenBlue = abs(rendered[index + 1] - rendered[index + 2])
          channelDifference = max(channelDifference, max(redGreen, greenBlue))
        }
        precondition(channelDifference < 0.0001, "Monochrome stock grain added color")
      }
      let darkSpread = grainSpread(stock, -2)
      let lightSpread = grainSpread(stock, 2)
      precondition(
        abs(darkSpread - lightSpread) > 0.001,
        "Density-stage grain did not react to stock exposure")
      print("Density grain stock \(stock): -2 EV \(darkSpread), +2 EV \(lightSpread)")
    }

    precondition(
      grainSpread(5, 0) < grainSpread(4, 0),
      "T-Max study texture is not finer than Tri-X")

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

    let signed = CIImage(
      color: CIColor(red: -0.1, green: 0.25, blue: 0.4, colorSpace: space)!
    ).cropped(to: source.extent)
    let signedTexture = FilmEffects.apply(
      to: signed, grain: 1, halation: 0, acutance: 1)
    let signedPixels = pixels(signedTexture, context: export)
    let center = (32 * 64 + 32) * 4
    precondition(abs(signedPixels[center] + 0.1) < 0.0001)
    precondition(abs(signedPixels[center + 1] - 0.25) < 0.0001)
    precondition(abs(signedPixels[center + 2] - 0.4) < 0.0001)
    print("Edge-detail checks passed; maximum working-format difference \(edgeDifference)")
  }
}

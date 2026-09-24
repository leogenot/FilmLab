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
    print("Deterministic grain checks passed; maximum working-format difference \(difference)")
  }
}

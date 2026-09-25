import CoreImage
import Foundation

@main
struct VersionedColorProbe {
  static func main() throws {
    guard CommandLine.arguments.count == 2 else {
      throw ProbeError.missingLibrary
    }
    let library = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
    let names = try Set(CIKernel.kernelNames(fromMetalLibraryData: library))
    precondition(names.contains("selectiveColor"))
    precondition(names.contains("preservingSelectiveColor"))
    let legacy = try CIColorKernel(functionName: "selectiveColor", fromMetalLibraryData: library)
    let preserving = try CIColorKernel(
      functionName: "preservingSelectiveColor", fromMetalLibraryData: library)
    let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
    let input = CIImage(
      color: CIColor(red: 0.8, green: 0.12, blue: 0.05, colorSpace: space)!
    ).cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
    let arguments: [Any] = [input, 0.0, 90.0, 45.0, 0.5]
    let context = CIContext(options: [
      .workingColorSpace: space,
      .workingFormat: CIFormat.RGBAf,
    ])
    func channels(_ image: CIImage) -> [Float] {
      var pixel = [Float](repeating: 0, count: 4)
      pixel.withUnsafeMutableBytes { bytes in
        context.render(
          image, toBitmap: bytes.baseAddress!, rowBytes: 16,
          bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
          format: .RGBAf, colorSpace: space)
      }
      return Array(pixel.prefix(3))
    }
    let bundledLegacy = channels(legacy.apply(extent: input.extent, arguments: arguments)!)
    let bundledNew = channels(preserving.apply(extent: input.extent, arguments: arguments)!)
    let runtimeLegacy = channels(
      SelectiveColor.apply(
        to: input, targetHue: 0, range: 90, hueShift: 45, saturation: 0.5,
        version: 1))
    let runtimeNew = channels(
      SelectiveColor.apply(
        to: input, targetHue: 0, range: 90, hueShift: 45, saturation: 0.5,
        version: 2))
    func difference(_ first: [Float], _ second: [Float]) -> Float {
      zip(first, second).map { abs($0 - $1) }.max() ?? 0
    }
    precondition(difference(bundledLegacy, bundledNew) > 0.001)
    precondition(difference(bundledLegacy, runtimeLegacy) < 0.0005)
    precondition(difference(bundledNew, runtimeNew) < 0.0005)

    precondition(names.contains("colorMixerBand"))
    precondition(names.contains("colorMixerBandV2"))
    let legacyMixer = try CIColorKernel(
      functionName: "colorMixerBand", fromMetalLibraryData: library)
    let newMixer = try CIColorKernel(
      functionName: "colorMixerBandV2", fromMetalLibraryData: library)
    let mixerArguments: [Any] = [input, input, 0.0, 30.0, 1.0, 0.0]
    let bundledOldMixer = channels(
      legacyMixer.apply(extent: input.extent, arguments: mixerArguments)!)
    let bundledNewMixer = channels(
      newMixer.apply(extent: input.extent, arguments: mixerArguments)!)
    var bands = Array(repeating: ColorMix(), count: 8)
    bands[0].hue = 30
    bands[0].saturation = 1
    let runtimeOldMixer = channels(ColorMixer.apply(to: input, adjustments: bands, version: 1))
    let runtimeNewMixer = channels(ColorMixer.apply(to: input, adjustments: bands, version: 2))
    precondition(difference(bundledOldMixer, bundledNewMixer) > 0.001)
    precondition(difference(bundledOldMixer, runtimeOldMixer) < 0.0005)
    precondition(difference(bundledNewMixer, runtimeNewMixer) < 0.0005)
    print("Bundled and development color kernels match; legacy versions remain distinct")
  }

  private enum ProbeError: Error {
    case missingLibrary
  }
}

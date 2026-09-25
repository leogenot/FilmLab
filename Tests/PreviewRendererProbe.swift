import CoreImage
import Foundation

@main
struct PreviewRendererProbe {
  static func main() async {
    let values: [Float] = [
      0.2, 0.3, 0.4, 1,
      1.25, 0.3, 0.4, 1,
    ]
    let image = values.withUnsafeBytes { bytes in
      CIImage(
        bitmapData: Data(bytes), bytesPerRow: 2 * 4 * MemoryLayout<Float>.size,
        size: CGSize(width: 2, height: 1), format: .RGBAf,
        colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!)
    }
    let renderer = PreviewRenderer()
    let result = await renderer.render(
      PreviewRequest(
        image: image, scale: 1, sourceURL: nil, originalImage: nil,
        showGamutWarning: false))
    precondition(result?.image.width == 2)
    precondition(result?.histogram?.outsideSRGBFraction == 0.5)
    precondition(result?.histogram?.redNearWhiteFraction == 0.5)
    precondition(result?.histogram?.greenNearWhiteFraction == 0)
    precondition(result?.histogram?.blueNearWhiteFraction == 0)
    precondition(result?.histogram?.redBins.count == 64)
    precondition(result?.histogram?.greenBins.count == 64)
    precondition(result?.histogram?.blueBins.count == 64)
    let warning = await renderer.render(
      PreviewRequest(
        image: image, scale: 1, sourceURL: nil, originalImage: nil,
        showGamutWarning: true))
    precondition(warning?.histogram?.outsideSRGBFraction == 0.5)
    guard let plainImage = result?.image, let warningImage = warning?.image,
      let plainData = plainImage.dataProvider?.data as Data?,
      let warningData = warningImage.dataProvider?.data as Data?
    else { preconditionFailure("Gamut warning preview is unreadable") }
    precondition(plainData != warningData, "Gamut warning did not change the preview")
    print("RGB output histogram, extended-linear gamut diagnostic, and preview warning passed")
  }
}

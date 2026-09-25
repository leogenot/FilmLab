import CoreImage
import Foundation

@main
struct PreviewRendererProbe {
  static func main() async throws {
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
    precondition(result?.histogram?.waveform.intensities.count == 64 * 64)
    precondition(result?.histogram?.waveform.intensities.contains(where: { $0 > 0 }) == true)
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
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-preview-parity-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let width = 64
    let height = 64
    var gradient = [Float](repeating: 0, count: width * height * 4)
    for y in 0..<height {
      for x in 0..<width {
        let offset = (y * width + x) * 4
        gradient[offset] = Float(x) / Float(width - 1) * 1.2
        gradient[offset + 1] = Float(y) / Float(height - 1) * 0.9
        gradient[offset + 2] = 0.15 + Float(x + y) / Float(width + height - 2) * 0.6
        gradient[offset + 3] = 1
      }
    }
    let gradientImage = gradient.withUnsafeBytes { bytes in
      CIImage(
        bitmapData: Data(bytes), bytesPerRow: width * 4 * MemoryLayout<Float>.size,
        size: CGSize(width: width, height: height), format: .RGBAf,
        colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!)
    }
    let preview = await renderer.render(
      PreviewRequest(
        image: gradientImage, scale: 1, sourceURL: nil, originalImage: nil,
        showGamutWarning: false))
    let floatPreview = await renderer.render(
      PreviewRequest(
        image: gradientImage, scale: 1, sourceURL: nil, originalImage: image,
        showGamutWarning: false, highPrecision: true))
    precondition(floatPreview?.original?.width == 2)
    precondition(floatPreview?.histogram?.redBins.count == 64)
    let exportURL = directory.appendingPathComponent("parity.tiff")
    try await ImageExporter().export(
      ExportRequest(image: gradientImage, url: exportURL, format: .tiff16SRGB, sourceURL: nil))
    guard let previewImage = preview?.image, let floatImage = floatPreview?.image,
      let exportedImage = CIImage(contentsOf: exportURL)
    else {
      preconditionFailure("Preview or TIFF export is unreadable")
    }
    let context = CIContext(options: [
      .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
    ])
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    func pixels(_ image: CIImage) -> [UInt8] {
      var output = [UInt8](repeating: 0, count: width * height * 4)
      output.withUnsafeMutableBytes { bytes in
        context.render(
          image, toBitmap: bytes.baseAddress!, rowBytes: width * 4,
          bounds: CGRect(x: 0, y: 0, width: width, height: height),
          format: .RGBA8, colorSpace: colorSpace)
      }
      return output
    }
    let previewPixels = pixels(CIImage(cgImage: previewImage))
    let floatPixels = pixels(CIImage(cgImage: floatImage))
    let exportPixels = pixels(exportedImage)
    let maximumDifference =
      zip(previewPixels, exportPixels).map {
        abs(Int($0) - Int($1))
      }.max() ?? 0
    precondition(
      maximumDifference <= 2, "Preview and TIFF export differ by \(maximumDifference) levels")
    let floatMaximumDifference =
      zip(floatPixels, exportPixels).map { abs(Int($0) - Int($1)) }.max() ?? 0
    precondition(
      floatMaximumDifference <= 2,
      "Float preview and TIFF export differ by \(floatMaximumDifference) levels")
    print("RGB output histogram, luminance waveform, gamut diagnostic, and warning passed")
    print("Preview and 16-bit sRGB TIFF agree within \(maximumDifference) 8-bit levels at 100%")
    print(
      "Float preview and 16-bit sRGB TIFF agree within \(floatMaximumDifference) 8-bit levels at 100%"
    )
  }
}

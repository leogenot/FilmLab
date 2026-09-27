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
    precondition(result?.histogram?.redWaveform.intensities.count == 64 * 64)
    precondition(result?.histogram?.greenWaveform.intensities.count == 64 * 64)
    precondition(result?.histogram?.blueWaveform.intensities.count == 64 * 64)
    let transparentValues: [Float] = [
      0, 0, 0, 0,
      1, 1, 1, 1,
    ]
    let transparentImage = transparentValues.withUnsafeBytes { bytes in
      CIImage(
        bitmapData: Data(bytes), bytesPerRow: 2 * 4 * MemoryLayout<Float>.size,
        size: CGSize(width: 2, height: 1), format: .RGBAf,
        colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!)
    }
    let transparentPreview = await renderer.render(
      PreviewRequest(
        image: transparentImage, scale: 1, sourceURL: nil, originalImage: nil,
        showGamutWarning: false))
    precondition(transparentPreview?.histogram?.blackFraction == 0)
    precondition(transparentPreview?.histogram?.whiteFraction == 1)
    precondition(transparentPreview?.histogram?.waveform.intensities[0] == 0)

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
    let compressedPreview = await renderer.render(
      PreviewRequest(
        image: image, scale: 1, sourceURL: nil, originalImage: image,
        showGamutWarning: false, compressSRGBGamut: true))
    guard let compressedImage = compressedPreview?.image,
      let compressedData = compressedImage.dataProvider?.data as Data?
    else { preconditionFailure("Compressed sRGB canvas is unreadable") }
    precondition(compressedData != plainData)
    precondition(compressedPreview?.histogram?.outsideSRGBFraction == 0.5)
    precondition(compressedPreview?.histogram?.greenBins != result?.histogram?.greenBins)
    precondition(compressedPreview?.original?.dataProvider?.data as Data? == plainData)
    let p3Space = CGColorSpace(name: CGColorSpace.displayP3)!
    let wideGreen = CIImage(
      color: CIColor(red: 0, green: 1, blue: 0, colorSpace: p3Space)!
    ).cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
    let srgbCanvas = await renderer.render(
      PreviewRequest(
        image: wideGreen, scale: 1, sourceURL: nil, originalImage: nil,
        showGamutWarning: false))
    let p3Canvas = await renderer.render(
      PreviewRequest(
        image: wideGreen, scale: 1, sourceURL: nil, originalImage: wideGreen,
        showGamutWarning: false, highPrecision: true, displayP3: true))
    guard let srgbImage = srgbCanvas?.image, let p3Image = p3Canvas?.image else {
      preconditionFailure("Wide-gamut canvas previews are unreadable")
    }
    precondition(srgbImage.colorSpace?.name == CGColorSpace.sRGB)
    precondition(p3Image.colorSpace?.name == CGColorSpace.displayP3)
    precondition(p3Image.bitsPerComponent == 16)
    precondition(p3Canvas?.original?.colorSpace?.name == CGColorSpace.displayP3)
    precondition(srgbCanvas?.histogram?.displayP3 == false)
    precondition(p3Canvas?.histogram?.displayP3 == true)
    precondition(
      srgbCanvas?.histogram?.outsideSRGBFraction == p3Canvas?.histogram?.outsideSRGBFraction)
    let wideOrange = CIImage(
      color: CIColor(red: 1, green: 0.5, blue: 0, colorSpace: p3Space)!
    ).cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
    let orangeSRGB = await renderer.render(
      PreviewRequest(
        image: wideOrange, scale: 1, sourceURL: nil, originalImage: nil,
        showGamutWarning: false))
    let orangeP3 = await renderer.render(
      PreviewRequest(
        image: wideOrange, scale: 1, sourceURL: nil, originalImage: nil,
        showGamutWarning: false, displayP3: true))
    precondition(
      orangeSRGB?.histogram?.greenBins != orangeP3?.histogram?.greenBins,
      "P3 scopes did not follow the P3 canvas values")
    precondition(
      orangeSRGB?.histogram?.outsideSRGBFraction == orangeP3?.histogram?.outsideSRGBFraction,
      "The sRGB gamut diagnostic changed with the canvas space")
    precondition(
      orangeSRGB?.histogram?.waveform.intensities
        != orangeP3?.histogram?.waveform.intensities,
      "P3 waveform did not follow the P3 canvas values")
    let p3Context = CIContext(options: [
      .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
      .workingFormat: CIFormat.RGBAf,
    ])
    func p3Green(_ image: CGImage) -> Float {
      var pixel = [Float](repeating: 0, count: 4)
      pixel.withUnsafeMutableBytes { bytes in
        p3Context.render(
          CIImage(cgImage: image), toBitmap: bytes.baseAddress!, rowBytes: 16,
          bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBAf,
          colorSpace: p3Space)
      }
      return pixel[1]
    }
    precondition(p3Green(p3Image) > p3Green(srgbImage) + 0.01)
    let p3WithSRGBCompression = await renderer.render(
      PreviewRequest(
        image: wideGreen, scale: 1, sourceURL: nil, originalImage: nil,
        showGamutWarning: false, highPrecision: true, displayP3: true,
        compressSRGBGamut: true))
    precondition(
      p3WithSRGBCompression?.image.dataProvider?.data as Data?
        == p3Image.dataProvider?.data as Data?)
    precondition(
      p3WithSRGBCompression?.histogram?.greenBins == p3Canvas?.histogram?.greenBins)
    func neutralPatch(_ value: CGFloat) -> CIImage {
      CIImage(
        color: CIColor(
          red: value, green: value, blue: value,
          colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!)!
      ).cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
    }
    let closeValues = [CGFloat(0.25), CGFloat(0.2505)]
    var precisePreviews = [PreviewResult?]()
    for value in closeValues {
      precisePreviews.append(
        await renderer.render(
          PreviewRequest(
            image: neutralPatch(value), scale: 1, sourceURL: nil, originalImage: nil,
            showGamutWarning: false, highPrecision: true)))
    }
    guard let firstPrecise = precisePreviews[0]?.image,
      let secondPrecise = precisePreviews[1]?.image
    else { preconditionFailure("16-bit canvas samples are unreadable") }
    func redLinear(_ image: CGImage) -> Float {
      var pixel = [Float](repeating: 0, count: 4)
      pixel.withUnsafeMutableBytes { bytes in
        p3Context.render(
          CIImage(cgImage: image), toBitmap: bytes.baseAddress!, rowBytes: 16,
          bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBAf,
          colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!)
      }
      return pixel[0]
    }
    precondition(redLinear(secondPrecise) > redLinear(firstPrecise) + 0.0003)
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
    precondition(floatPreview?.image.bitsPerComponent == 16)
    precondition(floatPreview?.original?.bitsPerComponent == 16)
    precondition(preview?.image.bitsPerComponent == 8)
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
    print(
      "RGB output histogram, luminance waveform, RGB parade, gamut diagnostic, and warning passed")
    print("Preview and 16-bit sRGB TIFF agree within \(maximumDifference) 8-bit levels at 100%")
    print(
      "Float preview and 16-bit sRGB TIFF agree within \(floatMaximumDifference) 8-bit levels at 100%"
    )
  }
}

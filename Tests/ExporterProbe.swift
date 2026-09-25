import CoreImage
import Foundation
import ImageIO

@main
struct ExporterProbe {
  static func main() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLabExporterProbe-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let sourceURL = directory.appendingPathComponent("source.jpg")
    let original = Data("unchanged source".utf8)
    try original.write(to: sourceURL)
    let firstBatchURL = BatchExportDestination.availableURL(
      for: sourceURL, in: directory, format: .jpeg)
    precondition(firstBatchURL.lastPathComponent == "source-FilmLab.jpg")
    try Data("preexisting export".utf8).write(to: firstBatchURL)
    let nextBatchURL = BatchExportDestination.availableURL(
      for: sourceURL, in: directory, format: .jpeg)
    precondition(nextBatchURL.lastPathComponent == "source-FilmLab-2.jpg")
    let image = CIImage(color: CIColor(red: 0.2, green: 0.4, blue: 0.6))
      .cropped(to: CGRect(x: 0, y: 0, width: 32, height: 24))
      .settingProperties([
        kCGImagePropertyOrientation as String: 8,
        kCGImagePropertyExifDictionary as String: [
          kCGImagePropertyExifPixelXDimension as String: 100,
          kCGImagePropertyExifPixelYDimension as String: 200,
          kCGImagePropertyExifDateTimeOriginal as String: "2025:03:09 15:13:37",
        ],
        kCGImagePropertyTIFFDictionary as String: [
          kCGImagePropertyTIFFMake as String: "FilmLab Test Camera",
          kCGImagePropertyTIFFOrientation as String: 8,
        ],
      ])
    let exporter = ImageExporter()

    do {
      try await exporter.export(
        ExportRequest(image: image, url: sourceURL, format: .jpeg, sourceURL: sourceURL))
      preconditionFailure("Export replaced the open source photo")
    } catch ExportError.wouldReplaceSource {
      let savedSource = try Data(contentsOf: sourceURL)
      precondition(savedSource == original)
    }

    let jpegURL = directory.appendingPathComponent("output.jpg")
    try await exporter.export(
      ExportRequest(image: image, url: jpegURL, format: .jpeg, sourceURL: sourceURL))
    guard let jpeg = CGImageSourceCreateWithURL(jpegURL as CFURL, nil),
      let jpegProperties = CGImageSourceCopyPropertiesAtIndex(jpeg, 0, nil) as? [String: Any],
      let jpegExif = jpegProperties[kCGImagePropertyExifDictionary as String] as? [String: Any],
      let jpegTIFF = jpegProperties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
    else { preconditionFailure("JPEG metadata is unreadable") }
    precondition(jpegProperties[kCGImagePropertyPixelWidth as String] as? Int == 32)
    precondition(jpegProperties[kCGImagePropertyPixelHeight as String] as? Int == 24)
    precondition(jpegExif[kCGImagePropertyExifPixelXDimension as String] as? Int == 32)
    precondition(jpegExif[kCGImagePropertyExifPixelYDimension as String] as? Int == 24)
    precondition(
      jpegExif[kCGImagePropertyExifDateTimeOriginal as String] as? String == "2025:03:09 15:13:37")
    precondition(jpegTIFF[kCGImagePropertyTIFFMake as String] as? String == "FilmLab Test Camera")
    precondition(jpegProperties[kCGImagePropertyOrientation as String] as? Int == 1)

    let tiffURL = directory.appendingPathComponent("output.tiff")
    try await exporter.export(
      ExportRequest(image: image, url: tiffURL, format: .tiff16DisplayP3, sourceURL: sourceURL))
    try await exporter.export(
      ExportRequest(image: image, url: tiffURL, format: .tiff16DisplayP3, sourceURL: sourceURL))
    guard let tiff = CGImageSourceCreateWithURL(tiffURL as CFURL, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(tiff, 0, nil) as? [String: Any],
      let tiffExif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
      let tiffTIFF = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
    else { preconditionFailure("TIFF replacement is unreadable") }
    precondition(properties[kCGImagePropertyDepth as String] as? Int == 16)
    let p3Image = CGImageSourceCreateImageAtIndex(tiff, 0, nil)
    precondition(p3Image?.colorSpace?.name == CGColorSpace.displayP3)
    precondition(properties[kCGImagePropertyPixelWidth as String] as? Int == 32)
    precondition(properties[kCGImagePropertyPixelHeight as String] as? Int == 24)
    precondition(properties[kCGImagePropertyOrientation as String] as? Int == 1)
    precondition(tiffTIFF[kCGImagePropertyTIFFOrientation as String] as? Int == 1)
    precondition(tiffTIFF[kCGImagePropertyTIFFMake as String] as? String == "FilmLab Test Camera")
    precondition(tiffExif[kCGImagePropertyExifPixelXDimension as String] as? Int == 32)
    precondition(tiffExif[kCGImagePropertyExifPixelYDimension as String] as? Int == 24)
    precondition(
      tiffExif[kCGImagePropertyExifDateTimeOriginal as String] as? String == "2025:03:09 15:13:37")
    let srgbURL = directory.appendingPathComponent("output-srgb.tiff")
    try await exporter.export(
      ExportRequest(image: image, url: srgbURL, format: .tiff16SRGB, sourceURL: sourceURL))
    guard let srgb = CGImageSourceCreateWithURL(srgbURL as CFURL, nil),
      let srgbImage = CGImageSourceCreateImageAtIndex(srgb, 0, nil),
      let srgbProperties = CGImageSourceCopyPropertiesAtIndex(srgb, 0, nil) as? [String: Any]
    else { preconditionFailure("sRGB TIFF is unreadable") }
    precondition(srgbImage.colorSpace?.name == CGColorSpace.sRGB)
    precondition(srgbProperties[kCGImagePropertyDepth as String] as? Int == 16)
    precondition(srgbProperties[kCGImagePropertyPixelWidth as String] as? Int == 32)
    precondition(srgbProperties[kCGImagePropertyPixelHeight as String] as? Int == 24)
    precondition(srgbProperties[kCGImagePropertyOrientation as String] as? Int == 1)
    let displayP3 = CGColorSpace(name: CGColorSpace.displayP3)!
    let wideGreen = CIImage(
      color: CIColor(red: 0, green: 1, blue: 0, colorSpace: displayP3)!
    ).cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
    let wideURL = directory.appendingPathComponent("wide-green-p3.tiff")
    let narrowURL = directory.appendingPathComponent("wide-green-srgb.tiff")
    try await exporter.export(
      ExportRequest(image: wideGreen, url: wideURL, format: .tiff16DisplayP3, sourceURL: nil))
    try await exporter.export(
      ExportRequest(image: wideGreen, url: narrowURL, format: .tiff16SRGB, sourceURL: nil))
    let context = CIContext(options: [
      .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
      .workingFormat: CIFormat.RGBAf,
    ])
    func p3Channels(_ url: URL) -> [Float] {
      let image = CIImage(contentsOf: url)!
      var pixel = [Float](repeating: 0, count: 4)
      pixel.withUnsafeMutableBytes { bytes in
        context.render(
          image, toBitmap: bytes.baseAddress!, rowBytes: 16,
          bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBAf,
          colorSpace: displayP3)
      }
      return pixel
    }
    let wide = p3Channels(wideURL)
    let narrow = p3Channels(narrowURL)
    precondition(wide[1] > narrow[1] + 0.01, "P3 TIFF lost wide green saturation")
    precondition(wide[0] + 0.05 < narrow[0], "sRGB TIFF retained out-of-gamut P3 green")
    let linearSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
    let vivid = CIImage(
      color: CIColor(red: 1.3, green: 0.1, blue: 0.05, colorSpace: linearSpace)!
    ).cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
    guard let mapped = OutputGamutMap.apply(to: vivid) else {
      preconditionFailure("sRGB gamut compression kernel unavailable")
    }
    func linearChannels(_ image: CIImage) -> [Float] {
      var pixel = [Float](repeating: 0, count: 4)
      pixel.withUnsafeMutableBytes { bytes in
        context.render(
          image, toBitmap: bytes.baseAddress!, rowBytes: 16,
          bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBAf,
          colorSpace: linearSpace)
      }
      return pixel
    }
    let compressed = linearChannels(mapped)
    let originalVivid = linearChannels(vivid)
    func luminance(_ channels: [Float]) -> Float {
      0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    }
    precondition(compressed.prefix(3).allSatisfy { $0 >= -0.0001 && $0 <= 1.0001 })
    precondition(abs(luminance(compressed) - luminance(originalVivid)) < 0.0001)
    precondition(abs(compressed[0] - 1) < 0.0001)
    let compressedURL = directory.appendingPathComponent("compressed-srgb.tiff")
    let unchangedP3URL = directory.appendingPathComponent("unchanged-p3.tiff")
    try await exporter.export(
      ExportRequest(
        image: vivid, url: compressedURL, format: .tiff16SRGB, sourceURL: nil,
        compressSRGBGamut: true))
    try await exporter.export(
      ExportRequest(
        image: vivid, url: unchangedP3URL, format: .tiff16DisplayP3, sourceURL: nil,
        compressSRGBGamut: true))
    let savedCompressed = linearChannels(CIImage(contentsOf: compressedURL)!)
    precondition(abs(savedCompressed[0] - compressed[0]) < 0.001)
    let savedP3 = linearChannels(CIImage(contentsOf: unchangedP3URL)!)
    precondition(savedP3[0] > savedCompressed[0] + 0.1)
    let savedSource = try Data(contentsOf: sourceURL)
    precondition(savedSource == original)
    print("Export source-protection, metadata and atomic TIFF checks passed")
  }
}

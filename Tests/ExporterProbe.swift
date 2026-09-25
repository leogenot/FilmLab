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
      ExportRequest(image: image, url: tiffURL, format: .tiff16, sourceURL: sourceURL))
    try await exporter.export(
      ExportRequest(image: image, url: tiffURL, format: .tiff16, sourceURL: sourceURL))
    guard let tiff = CGImageSourceCreateWithURL(tiffURL as CFURL, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(tiff, 0, nil) as? [String: Any]
    else { preconditionFailure("TIFF replacement is unreadable") }
    precondition(properties[kCGImagePropertyDepth as String] as? Int == 16)
    let savedSource = try Data(contentsOf: sourceURL)
    precondition(savedSource == original)
    print("Export source-protection and atomic TIFF checks passed")
  }
}

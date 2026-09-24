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
    precondition(CGImageSourceCreateWithURL(jpegURL as CFURL, nil) != nil)

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

import CoreImage
import Foundation
import ImageIO

enum ExportFormat: Sendable {
  case jpeg
  case tiff16
}

struct ExportRequest: @unchecked Sendable {
  let image: CIImage
  let url: URL
  let format: ExportFormat
  let sourceURL: URL?
}

actor ImageExporter {
  private let context = CIContext(options: [
    .useSoftwareRenderer: false,
    .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
    .workingFormat: CIFormat.RGBAf,
  ])

  func export(_ request: ExportRequest) throws {
    if let sourceURL = request.sourceURL,
      request.url.standardizedFileURL.resolvingSymlinksInPath()
        == sourceURL.standardizedFileURL.resolvingSymlinksInPath()
    {
      throw ExportError.wouldReplaceSource
    }
    let accessing = request.sourceURL?.startAccessingSecurityScopedResource() ?? false
    defer { if accessing { request.sourceURL?.stopAccessingSecurityScopedResource() } }
    let image = request.image.settingProperties(normalizedOutputProperties(for: request.image))
    switch request.format {
    case .jpeg:
      let quality = CIImageRepresentationOption(
        rawValue: kCGImageDestinationLossyCompressionQuality as String)
      guard
        let data = context.jpegRepresentation(
          of: image,
          colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, options: [quality: 0.95]
        )
      else {
        throw ExportError.renderFailed
      }
      try data.write(to: request.url, options: .atomic)
    case .tiff16:
      let temporaryURL = request.url.deletingLastPathComponent()
        .appendingPathComponent(".FilmLab-\(UUID().uuidString).tiff")
      defer { try? FileManager.default.removeItem(at: temporaryURL) }
      try context.writeTIFFRepresentation(
        of: image, to: temporaryURL, format: .RGBA16,
        colorSpace: CGColorSpace(name: CGColorSpace.displayP3)!, options: [:]
      )
      if FileManager.default.fileExists(atPath: request.url.path) {
        _ = try FileManager.default.replaceItemAt(request.url, withItemAt: temporaryURL)
      } else {
        try FileManager.default.moveItem(at: temporaryURL, to: request.url)
      }
    }
  }

  private func normalizedOutputProperties(for image: CIImage) -> [String: Any] {
    let extent = image.extent.integral
    var properties = image.properties
    var exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
    exif[kCGImagePropertyExifPixelXDimension as String] = Int(extent.width)
    exif[kCGImagePropertyExifPixelYDimension as String] = Int(extent.height)
    properties[kCGImagePropertyExifDictionary as String] = exif
    properties[kCGImagePropertyOrientation as String] = 1
    var tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
    tiff[kCGImagePropertyTIFFOrientation as String] = 1
    properties[kCGImagePropertyTIFFDictionary as String] = tiff
    return properties
  }
}

enum ExportError: LocalizedError {
  case renderFailed
  case wouldReplaceSource

  var errorDescription: String? {
    switch self {
    case .renderFailed: "Could not render the photo for export."
    case .wouldReplaceSource: "Choose another name so the original photo stays unchanged."
    }
  }
}

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
    switch request.format {
    case .jpeg:
      let quality = CIImageRepresentationOption(
        rawValue: kCGImageDestinationLossyCompressionQuality as String)
      guard
        let data = context.jpegRepresentation(
          of: request.image,
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
        of: request.image, to: temporaryURL, format: .RGBA16,
        colorSpace: CGColorSpace(name: CGColorSpace.displayP3)!, options: [:]
      )
      if FileManager.default.fileExists(atPath: request.url.path) {
        _ = try FileManager.default.replaceItemAt(request.url, withItemAt: temporaryURL)
      } else {
        try FileManager.default.moveItem(at: temporaryURL, to: request.url)
      }
    }
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

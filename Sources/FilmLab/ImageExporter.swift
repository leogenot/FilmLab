import CoreImage
import Foundation
import ImageIO

enum ExportFormat: Sendable, Equatable {
  case jpeg
  case tiff16SRGB
  case tiff16DisplayP3
  case tiff32Linear

  var fileExtension: String {
    self == .jpeg ? "jpg" : "tiff"
  }
}

enum BatchExportDestination {
  static func availableURL(for source: URL, in directory: URL, format: ExportFormat) -> URL {
    let base = source.deletingPathExtension().lastPathComponent + "-FilmLab"
    var candidate = directory.appendingPathComponent(base).appendingPathExtension(
      format.fileExtension)
    var suffix = 2
    while FileManager.default.fileExists(atPath: candidate.path) {
      candidate = directory.appendingPathComponent("\(base)-\(suffix)")
        .appendingPathExtension(format.fileExtension)
      suffix += 1
    }
    return candidate
  }
}

struct ExportRequest: @unchecked Sendable {
  let image: CIImage
  let url: URL
  let format: ExportFormat
  let sourceURL: URL?
  let compressSRGBGamut: Bool

  init(
    image: CIImage, url: URL, format: ExportFormat, sourceURL: URL?,
    compressSRGBGamut: Bool = false
  ) {
    self.image = image
    self.url = url
    self.format = format
    self.sourceURL = sourceURL
    self.compressSRGBGamut = compressSRGBGamut
  }
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
    let outputImage: CIImage
    if request.compressSRGBGamut && (request.format == .jpeg || request.format == .tiff16SRGB) {
      guard let mapped = OutputGamutMap.apply(to: request.image) else {
        throw ExportError.renderFailed
      }
      outputImage = mapped
    } else {
      outputImage = request.image
    }
    let image = outputImage.settingProperties(normalizedOutputProperties(for: request.image))
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
    case .tiff16SRGB, .tiff16DisplayP3, .tiff32Linear:
      let outputFormat: CIFormat
      let outputSpaceName: CFString
      switch request.format {
      case .tiff16SRGB:
        outputFormat = .RGBA16
        outputSpaceName = CGColorSpace.sRGB
      case .tiff16DisplayP3:
        outputFormat = .RGBA16
        outputSpaceName = CGColorSpace.displayP3
      case .tiff32Linear:
        outputFormat = .RGBAf
        outputSpaceName = CGColorSpace.extendedLinearSRGB
      case .jpeg:
        preconditionFailure("JPEG is handled above")
      }
      let temporaryURL = request.url.deletingLastPathComponent()
        .appendingPathComponent(".FilmLab-\(UUID().uuidString).tiff")
      defer { try? FileManager.default.removeItem(at: temporaryURL) }
      try context.writeTIFFRepresentation(
        of: image, to: temporaryURL, format: outputFormat,
        colorSpace: CGColorSpace(name: outputSpaceName)!, options: [:]
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

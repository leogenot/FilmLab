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
      try context.writeTIFFRepresentation(
        of: request.image, to: request.url, format: .RGBA16,
        colorSpace: CGColorSpace(name: CGColorSpace.displayP3)!, options: [:]
      )
    }
  }
}

enum ExportError: LocalizedError {
  case renderFailed
  var errorDescription: String? { "Could not render the photo for export." }
}

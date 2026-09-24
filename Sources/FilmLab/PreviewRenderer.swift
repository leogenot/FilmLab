import CoreImage

struct PreviewRequest: @unchecked Sendable {
  let image: CIImage
  let scale: CGFloat
  let sourceURL: URL?
  let originalImage: CIImage?
}

struct PreviewResult: @unchecked Sendable {
  let image: CGImage
  let original: CGImage?
}

actor PreviewRenderer {
  private let context = CIContext(options: [
    .useSoftwareRenderer: false,
    .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
    .workingFormat: CIFormat.RGBAh,
  ])

  func render(_ request: PreviewRequest) -> PreviewResult? {
    let accessing = request.sourceURL?.startAccessingSecurityScopedResource() ?? false
    defer { if accessing { request.sourceURL?.stopAccessingSecurityScopedResource() } }
    guard !Task.isCancelled else { return nil }
    guard let image = renderImage(request.image, scale: request.scale) else { return nil }
    let original = request.originalImage.flatMap { renderImage($0, scale: request.scale) }
    guard !Task.isCancelled, request.originalImage == nil || original != nil else { return nil }
    return PreviewResult(image: image, original: original)
  }

  private func renderImage(_ source: CIImage, scale: CGFloat) -> CGImage? {
    let reduced = source.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    guard !Task.isCancelled else { return nil }
    return context.createCGImage(
      reduced, from: reduced.extent, format: .RGBA8,
      colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
  }
}

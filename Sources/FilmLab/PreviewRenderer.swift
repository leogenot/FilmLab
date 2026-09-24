import CoreImage

struct PreviewRequest: @unchecked Sendable {
  let image: CIImage
  let scale: CGFloat
  let sourceURL: URL?
}

struct PreviewResult: @unchecked Sendable {
  let image: CGImage
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
    let reduced = request.image.transformed(
      by: CGAffineTransform(scaleX: request.scale, y: request.scale))
    guard !Task.isCancelled,
      let image = context.createCGImage(
        reduced, from: reduced.extent, format: .RGBA8,
        colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
    else { return nil }
    return PreviewResult(image: image)
  }
}

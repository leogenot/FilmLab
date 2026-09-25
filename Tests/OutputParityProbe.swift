import CoreImage
import Foundation
import ImageIO

private enum ProbeError: Error { case unreadable }

// ImageDecoder's app-facing error is declared in main.swift, which this standalone probe omits.
enum EditorError: LocalizedError {
  case unsupported
}

@main
struct OutputParityProbe {
  static func main() async throws {
    guard CommandLine.arguments.count == 3 else {
      fatalError("Pass a disposable RAW and JPEG path")
    }
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-output-parity-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let decoder = ImageDecoder()
    let previewRenderer = PreviewRenderer()
    let exporter = ImageExporter()
    let context = CIContext(options: [
      .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
      .workingFormat: CIFormat.RGBAf,
    ])
    let outputSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let stock = FilmKernels.kernel("filmResponse") else { throw ProbeError.unreadable }

    for (kind, path) in zip(["RAW", "JPEG"], CommandLine.arguments.dropFirst()) {
      let url = URL(fileURLWithPath: path)
      let decoded = try await decoder.decode(
        from: url, isRAW: kind == "RAW", flatRAW: kind == "RAW",
        highlightRecovery: true, temperature: nil, tint: nil)
      let extent = decoded.image.extent.integral
      let crop = CGRect(
        x: extent.midX - 1024, y: extent.midY - 1536, width: 2048, height: 3072
      )
      .intersection(extent)
      let source = decoded.image.cropped(to: crop)
        .transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
      let width = Int(source.extent.width / 2)
      let height = Int(source.extent.height / 2)
      precondition(width == 1024 && height == 1536)

      func pixels(_ image: CIImage) -> [UInt8] {
        var result = [UInt8](repeating: 0, count: width * height * 4)
        result.withUnsafeMutableBytes { bytes in
          context.render(
            image, toBitmap: bytes.baseAddress!, rowBytes: width * 4,
            bounds: CGRect(x: 0, y: 0, width: width, height: height),
            format: .RGBA8, colorSpace: outputSpace)
        }
        return result
      }

      for exposure in [-2.0, 0.0, 2.0] {
        guard
          let developed = stock.apply(
            extent: source.extent,
            arguments: [source, exposure, 0.0, kind == "RAW" ? 1.0 : 0.7])
        else { throw ProbeError.unreadable }
        let preview = await previewRenderer.render(
          PreviewRequest(
            image: developed, scale: 0.5, sourceURL: url,
            originalImage: nil, showGamutWarning: false))
        guard let previewImage = preview?.image else { throw ProbeError.unreadable }
        let previewPixels = pixels(CIImage(cgImage: previewImage))
        let widePreview = await previewRenderer.render(
          PreviewRequest(
            image: developed, scale: 0.5, sourceURL: url,
            originalImage: nil, showGamutWarning: false,
            highPrecision: true, displayP3: true))
        guard let widePreviewImage = widePreview?.image else { throw ProbeError.unreadable }
        precondition(widePreviewImage.bitsPerComponent == 16)
        precondition(widePreviewImage.colorSpace?.name == CGColorSpace.displayP3)
        let widePreviewPixels = pixels(CIImage(cgImage: widePreviewImage))

        for format in [ExportFormat.tiff16SRGB, .tiff16DisplayP3, .jpeg] {
          let formatName =
            switch format {
            case .tiff16SRGB: "srgb-tiff"
            case .tiff16DisplayP3: "p3-tiff"
            case .jpeg: "jpeg"
            }
          let outputURL = directory.appendingPathComponent(
            "\(kind)-\(exposure)-\(formatName).\(format.fileExtension)"
          )
          try await exporter.export(
            ExportRequest(image: developed, url: outputURL, format: format, sourceURL: url))
          guard let exported = CIImage(contentsOf: outputURL) else { throw ProbeError.unreadable }
          if format == .tiff16DisplayP3 {
            guard let file = CGImageSourceCreateWithURL(outputURL as CFURL, nil),
              let metadata = CGImageSourceCopyPropertiesAtIndex(file, 0, nil)
                as? [String: Any],
              let cgImage = CGImageSourceCreateImageAtIndex(file, 0, nil)
            else { throw ProbeError.unreadable }
            precondition(cgImage.colorSpace?.name == CGColorSpace.displayP3)
            precondition(metadata[kCGImagePropertyDepth as String] as? Int == 16)
          }
          let reduced = exported.applyingFilter(
            "CILanczosScaleTransform",
            parameters: [kCIInputScaleKey: 0.5, kCIInputAspectRatioKey: 1])
          let exportedPixels = pixels(reduced)
          var absoluteSum = 0
          var maximum = 0
          let comparisonPixels = format == .tiff16DisplayP3 ? widePreviewPixels : previewPixels
          for index in stride(from: 0, to: comparisonPixels.count, by: 4) {
            for channel in 0..<3 {
              let difference = abs(
                Int(comparisonPixels[index + channel]) - Int(exportedPixels[index + channel]))
              absoluteSum += difference
              maximum = max(maximum, difference)
            }
          }
          let mean = Double(absoluteSum) / Double(width * height * 3)
          print("\(kind) \(exposure) EV \(format): mean \(mean), max \(maximum) / 255")
          precondition(mean < (format == .jpeg ? 2 : 1), "Large preview/export drift")
        }
      }
    }
  }
}

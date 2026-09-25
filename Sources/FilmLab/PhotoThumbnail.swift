import AppKit
import CoreImage
import ImageIO
import SwiftUI

struct PhotoThumbnail: View {
  let path: String
  let refreshToken: Int
  let activePreview: NSImage?
  @State private var image: NSImage?

  var body: some View {
    Group {
      if let activePreview {
        Image(nsImage: activePreview)
          .resizable()
          .scaledToFill()
      } else if let image {
        Image(nsImage: image)
          .resizable()
          .scaledToFill()
      } else {
        Image(
          systemName: FileManager.default.fileExists(atPath: path)
            ? "photo" : "photo.badge.exclamationmark"
        )
        .foregroundStyle(.secondary)
      }
    }
    .clipped()
    .task(id: "\(path)#\(refreshToken)") {
      image = nil
      if let original = await ThumbnailLoader.shared.loadOriginal(path), !Task.isCancelled {
        image = NSImage(
          cgImage: original.image,
          size: NSSize(width: original.image.width, height: original.image.height))
      }
      if let edited = await ThumbnailLoader.shared.loadEdited(path, refreshToken: refreshToken),
        !Task.isCancelled
      {
        image = NSImage(
          cgImage: edited.image,
          size: NSSize(width: edited.image.width, height: edited.image.height))
      }
    }
  }
}

private struct SendableThumbnail: @unchecked Sendable {
  let image: CGImage
}

private actor ThumbnailLoader {
  static let shared = ThumbnailLoader()
  private var originals: [String: SendableThumbnail] = [:]
  private var edited: [String: (refreshToken: Int, thumbnail: SendableThumbnail?)] = [:]
  private var order: [String] = []
  private let capacity = 128

  func loadOriginal(_ path: String) -> SendableThumbnail? {
    if let original = originals[path] { return original }
    guard !Task.isCancelled else { return nil }
    let url = URL(fileURLWithPath: path) as CFURL
    let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
    guard let source = CGImageSourceCreateWithURL(url, sourceOptions as CFDictionary) else {
      return nil
    }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: 320,
    ]
    guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    else { return nil }
    let result = SendableThumbnail(image: thumbnail)
    originals[path] = result
    order.append(path)
    if order.count > capacity {
      let evicted = order.removeFirst()
      originals.removeValue(forKey: evicted)
      edited.removeValue(forKey: evicted)
    }
    return result
  }

  func loadEdited(_ path: String, refreshToken: Int) async -> SendableThumbnail? {
    if let cached = edited[path], cached.refreshToken == refreshToken {
      return cached.thumbnail
    }
    guard !Task.isCancelled else { return nil }
    let rendered = await PhotoEditor.renderedThumbnail(for: URL(fileURLWithPath: path))
    guard !Task.isCancelled else { return nil }
    let result = rendered.map { SendableThumbnail(image: $0) }
    edited[path] = (refreshToken, result)
    return result
  }
}

actor EditedThumbnailRenderer {
  static let shared = EditedThumbnailRenderer()
  private let context = CIContext(options: [
    .useSoftwareRenderer: false,
    .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
    .workingFormat: CIFormat.RGBAh,
  ])

  func render(_ source: CIImage) -> CGImage? {
    guard !Task.isCancelled else { return nil }
    let scale = min(1, 320 / max(source.extent.width, source.extent.height))
    let reduced = source.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    return context.createCGImage(
      reduced, from: reduced.extent, format: .RGBA8,
      colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
  }
}

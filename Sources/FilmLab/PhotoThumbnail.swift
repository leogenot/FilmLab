import AppKit
import ImageIO
import SwiftUI

struct PhotoThumbnail: View {
  let path: String
  @State private var image: NSImage?

  var body: some View {
    Group {
      if let image {
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
    .task(id: path) {
      guard let thumbnail = await ThumbnailLoader.shared.load(path), !Task.isCancelled else {
        image = nil
        return
      }
      image = NSImage(
        cgImage: thumbnail.image,
        size: NSSize(width: thumbnail.image.width, height: thumbnail.image.height))
    }
  }
}

private struct SendableThumbnail: @unchecked Sendable {
  let image: CGImage
}

private actor ThumbnailLoader {
  static let shared = ThumbnailLoader()
  private var cached: [String: SendableThumbnail] = [:]
  private var order: [String] = []
  private let capacity = 128

  func load(_ path: String) -> SendableThumbnail? {
    if let cached = cached[path] { return cached }
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
    cached[path] = result
    order.append(path)
    if order.count > capacity {
      cached.removeValue(forKey: order.removeFirst())
    }
    return result
  }
}

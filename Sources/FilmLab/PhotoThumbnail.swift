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
      image = Self.load(path)
    }
  }

  private static func load(_ path: String) -> NSImage? {
    let url = URL(fileURLWithPath: path) as CFURL
    guard let source = CGImageSourceCreateWithURL(url, nil) else { return nil }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: 320,
    ]
    guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    else { return nil }
    return NSImage(
      cgImage: thumbnail, size: NSSize(width: thumbnail.width, height: thumbnail.height))
  }
}

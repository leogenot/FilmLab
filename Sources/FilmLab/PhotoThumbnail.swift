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
    .task(id: "\(path)#\(refreshToken)#\(activePreview == nil)") {
      image = nil
      guard activePreview == nil else { return }
      if let cached = await ThumbnailLoader.shared.cachedEdited(path), !Task.isCancelled {
        image = NSImage(
          cgImage: cached.image,
          size: NSSize(width: cached.image.width, height: cached.image.height))
        return
      }
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
  private struct EditedKey: Hashable, Sendable {
    let path: String
    let refreshToken: Int
    let signature: String
  }
  private let queue = RenderWorkQueue<EditedKey, SendableThumbnail>(maxConcurrent: 2) { key in
    await PhotoEditor.renderedThumbnail(for: URL(fileURLWithPath: key.path)).map {
      SendableThumbnail(image: $0)
    }
  }
  private var originals: [String: (signature: String, thumbnail: SendableThumbnail)] = [:]
  private var edited: [String: (signature: String, thumbnail: SendableThumbnail?)] = [:]
  private var order: [String] = []
  private let capacity = 128
  private let diskCache = ThumbnailDiskCache()
  private let editsDirectory = FileManager.default.urls(
    for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("FilmLab/Edits", isDirectory: true)

  private func remember(_ path: String) {
    guard !order.contains(path) else { return }
    order.append(path)
    if order.count > capacity {
      let evicted = order.removeFirst()
      originals.removeValue(forKey: evicted)
      edited.removeValue(forKey: evicted)
    }
  }

  func loadOriginal(_ path: String) -> SendableThumbnail? {
    let signature = ThumbnailCacheSignature.source(for: URL(fileURLWithPath: path))
    if let signature, let original = originals[path], original.signature == signature {
      return original.thumbnail
    }
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
    if let signature {
      originals[path] = (signature, result)
      remember(path)
    }
    return result
  }

  func cachedEdited(_ path: String) -> SendableThumbnail? {
    let url = URL(fileURLWithPath: path)
    guard
      let signature = ThumbnailCacheSignature.developed(
        for: url, editsDirectory: editsDirectory)
    else { return nil }
    if let cached = edited[path], cached.signature == signature {
      return cached.thumbnail
    }
    if let diskImage = diskCache.load(path: path, signature: signature) {
      let cached = SendableThumbnail(image: diskImage)
      edited[path] = (signature, cached)
      remember(path)
      return cached
    }
    return nil
  }

  func loadEdited(_ path: String, refreshToken: Int) async -> SendableThumbnail? {
    if let cached = cachedEdited(path) { return cached }
    let url = URL(fileURLWithPath: path)
    let signature = ThumbnailCacheSignature.developed(for: url, editsDirectory: editsDirectory)
    guard !Task.isCancelled else { return nil }
    let rendered = await queue.value(
      for: EditedKey(path: path, refreshToken: refreshToken, signature: signature ?? "uncacheable"))
    guard !Task.isCancelled else { return nil }
    guard let signature else { return rendered }
    guard ThumbnailCacheSignature.developed(for: url, editsDirectory: editsDirectory) == signature
    else { return nil }
    if let rendered {
      edited[path] = (signature, rendered)
      remember(path)
      diskCache.save(rendered.image, path: path, signature: signature)
    }
    return rendered
  }
}

actor EditedThumbnailRenderer {
  static let shared = EditedThumbnailRenderer()
  private let context = CIContext(options: [
    .useSoftwareRenderer: false,
    .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
    .workingFormat: CIFormat.RGBAf,
  ])

  func render(
    _ source: CIImage, maxDimension: CGFloat = 320, displayP3: Bool = false,
    highPrecision: Bool = false
  ) -> CGImage? {
    guard !Task.isCancelled else { return nil }
    let scale = min(1, maxDimension / max(source.extent.width, source.extent.height))
    let reduced =
      scale < 1
      ? source.applyingFilter(
        "CILanczosScaleTransform",
        parameters: [kCIInputScaleKey: scale, kCIInputAspectRatioKey: 1])
      : source
    return context.createCGImage(
      reduced, from: reduced.extent, format: highPrecision ? .RGBA16 : .RGBA8,
      colorSpace: CGColorSpace(name: displayP3 ? CGColorSpace.displayP3 : CGColorSpace.sRGB)!)
  }
}

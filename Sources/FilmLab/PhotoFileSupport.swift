import Foundation
import ImageIO
import UniformTypeIdentifiers

enum PhotoFileSupport {
  static func hasImageHeader(_ url: URL) -> Bool {
    rawStatus(url) != nil
  }

  static func rawStatus(_ url: URL) -> Bool? {
    guard
      let source = CGImageSourceCreateWithURL(
        url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
      CGImageSourceGetCount(source) > 0,
      let identifier = CGImageSourceGetType(source) as String?,
      let detectedType = UTType(identifier),
      detectedType.conforms(to: .image) || detectedType.conforms(to: .rawImage)
    else { return nil }
    return detectedType.conforms(to: .rawImage)
  }
}

import Foundation
import ImageIO
import UniformTypeIdentifiers

enum PhotoFileSupport {
  static func hasImageHeader(_ url: URL) -> Bool {
    guard
      let source = CGImageSourceCreateWithURL(
        url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
      CGImageSourceGetCount(source) > 0,
      let identifier = CGImageSourceGetType(source) as String?,
      let detectedType = UTType(identifier)
    else { return false }
    return detectedType.conforms(to: .image) || detectedType.conforms(to: .rawImage)
  }
}

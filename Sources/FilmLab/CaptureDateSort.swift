import Foundation
import ImageIO

enum CaptureDateSort {
  static func dates(for paths: [String]) -> [String: Date] {
    var result: [String: Date] = [:]
    for path in paths {
      if Task.isCancelled { break }
      let url = URL(fileURLWithPath: path)
      guard
        let source = CGImageSourceCreateWithURL(
          url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
        let date = captureDate(in: properties)
      else { continue }
      result[path] = date
    }
    return result
  }

  static func newestFirst(_ paths: [String], dates: [String: Date]) -> [String] {
    paths.enumerated().sorted { left, right in
      switch (dates[left.element], dates[right.element]) {
      case (let lhs?, let rhs?) where lhs != rhs: return lhs > rhs
      case (_?, nil): return true
      case (nil, _?): return false
      default: return left.offset < right.offset
      }
    }.map(\.element)
  }

  static func captureDate(in properties: [String: Any]) -> Date? {
    let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
    let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
    let original = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String
    let offset = exif[kCGImagePropertyExifOffsetTimeOriginal as String] as? String
    if let original, let offset, let date = parse(original, offset: offset) { return date }
    if let original, let date = parse(original) { return date }
    if let recorded = tiff[kCGImagePropertyTIFFDateTime as String] as? String {
      return parse(recorded)
    }
    return nil
  }

  private static func parse(_ value: String, offset: String? = nil) -> Date? {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.isLenient = false
    formatter.dateFormat = offset == nil ? "yyyy:MM:dd HH:mm:ss" : "yyyy:MM:dd HH:mm:ssXXXXX"
    return formatter.date(from: value + (offset ?? ""))
  }
}

import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// An evictable cache of small, developed previews; originals and edit records remain authoritative.
struct ThumbnailDiskCache {
  private struct Entry: Codable {
    let signature: String
    let png: Data
  }

  let directory: URL
  let capacity: Int

  init(directory: URL? = nil, capacity: Int = 128) {
    self.directory =
      directory
      ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("FilmLab/Thumbnails", isDirectory: true)
    self.capacity = max(1, capacity)
  }

  func load(path: String, signature: String) -> CGImage? {
    let url = fileURL(for: path)
    guard let data = try? Data(contentsOf: url),
      let entry = try? JSONDecoder().decode(Entry.self, from: data),
      entry.signature == signature,
      let source = CGImageSourceCreateWithData(entry.png as CFData, nil)
    else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
  }

  func save(_ image: CGImage, path: String, signature: String) {
    let data = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(
        data, UTType.png.identifier as CFString, 1, nil)
    else { return }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { return }
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let entry = Entry(signature: signature, png: data as Data)
      let writtenURL = fileURL(for: path)
      try JSONEncoder().encode(entry).write(to: writtenURL, options: .atomic)
      prune(keeping: writtenURL)
    } catch {
      // Preview caching is optional; a failed write must not interrupt editing.
    }
  }

  private func fileURL(for path: String) -> URL {
    let digest = SHA256.hash(data: Data(path.utf8))
      .map { String(format: "%02x", $0) }.joined()
    return directory.appendingPathComponent(digest + ".json")
  }

  private func prune(keeping writtenURL: URL) {
    guard
      let files = try? FileManager.default.contentsOfDirectory(
        at: directory, includingPropertiesForKeys: [.contentModificationDateKey],
        options: [.skipsHiddenFiles])
    else { return }
    let excess = files.count - capacity
    guard excess > 0 else { return }
    let oldest = files.filter { $0 != writtenURL }.sorted {
      let first =
        (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?
        .contentModificationDate ?? .distantPast
      let second =
        (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?
        .contentModificationDate ?? .distantPast
      return first < second
    }
    for url in oldest.prefix(excess) { try? FileManager.default.removeItem(at: url) }
  }
}

enum ThumbnailCacheSignature {
  static func source(for url: URL) -> String? {
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
      let size = attributes[.size] as? NSNumber,
      let modified = attributes[.modificationDate] as? Date,
      let created = attributes[.creationDate] as? Date,
      let fileNumber = attributes[.systemFileNumber] as? NSNumber
    else { return nil }
    let parts = [
      url.standardizedFileURL.path,
      size.stringValue,
      String(modified.timeIntervalSince1970.bitPattern),
      String(created.timeIntervalSince1970.bitPattern),
      fileNumber.stringValue,
    ]
    return digest(Data(parts.joined(separator: "\n").utf8))
  }

  static func developed(for url: URL, editsDirectory: URL) -> String? {
    guard let source = source(for: url) else { return nil }
    let location = EditRecordLocator.locate(sourceURL: url, directory: editsDirectory)
    var parts = [source, rendererVersion]
    for editURL in [location.primaryURL, location.pathURL] {
      guard FileManager.default.fileExists(atPath: editURL.path) else {
        parts.append("missing")
        continue
      }
      guard let data = try? Data(contentsOf: editURL) else { return nil }
      parts.append(editDigest(data))
    }
    return digest(Data(parts.joined(separator: "\n").utf8))
  }

  private static let rendererVersion: String = {
    guard let executable = Bundle.main.executableURL,
      let attributes = try? FileManager.default.attributesOfItem(atPath: executable.path),
      let size = attributes[.size] as? NSNumber,
      let modified = attributes[.modificationDate] as? Date
    else { return "unknown-build" }
    return "thumbnail-v1-\(size)-\(modified.timeIntervalSince1970.bitPattern)"
  }()

  private static func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  private static func editDigest(_ data: Data) -> String {
    guard let value = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
      let canonical = try? JSONSerialization.data(
        withJSONObject: value, options: [.sortedKeys, .fragmentsAllowed])
    else { return digest(data) }
    return digest(canonical)
  }
}

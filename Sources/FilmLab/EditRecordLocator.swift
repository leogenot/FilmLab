import CryptoKit
import Foundation

struct EditRecordLocation {
  let primaryURL: URL
  let pathURL: URL
  let migrationNotice: String?
}

enum EditRecordLocator {
  static func locate(sourceURL: URL, directory: URL) -> EditRecordLocation {
    let pathURL = directory.appendingPathComponent(
      digest(sourceURL.standardizedFileURL.path) + ".json")
    guard let identity = fileIdentity(for: sourceURL) else {
      return EditRecordLocation(primaryURL: pathURL, pathURL: pathURL, migrationNotice: nil)
    }
    let stableURL = directory.appendingPathComponent("ByFileID", isDirectory: true)
      .appendingPathComponent(digest(identity) + ".json")
    if FileManager.default.fileExists(atPath: stableURL.path) {
      return EditRecordLocation(primaryURL: stableURL, pathURL: pathURL, migrationNotice: nil)
    }
    if FileManager.default.fileExists(atPath: pathURL.path) {
      do {
        try FileManager.default.createDirectory(
          at: stableURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: pathURL, to: stableURL)
      } catch {
        return EditRecordLocation(
          primaryURL: pathURL, pathURL: pathURL,
          migrationNotice:
            "Saved edits could not be linked to this file. They may not follow a rename until the file can be saved: \(error.localizedDescription)"
        )
      }
    }
    return EditRecordLocation(primaryURL: stableURL, pathURL: pathURL, migrationNotice: nil)
  }

  private static func fileIdentity(for url: URL) -> String? {
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
      let volume = attributes[.systemNumber] as? NSNumber,
      let number = attributes[.systemFileNumber] as? NSNumber,
      let created = attributes[.creationDate] as? Date
    else { return nil }
    let volumeID =
      (try? url.resourceValues(forKeys: [.volumeUUIDStringKey]))?.volumeUUIDString
      ?? volume.stringValue
    let createdMilliseconds = Int64(created.timeIntervalSince1970 * 1_000)
    return "\(volumeID):\(number.uint64Value):\(createdMilliseconds)"
  }

  private static func digest(_ value: String) -> String {
    SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
  }
}

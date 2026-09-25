import Foundation

struct SavedEditLoad<Value> {
  var value: Value
  let notice: String?
  let canSave: Bool
  let backupURL: URL?
}

enum SavedEditStore {
  static func load<Value: Codable>(
    from primaryURL: URL, fallbackURL: URL, defaultValue: Value
  ) -> SavedEditLoad<Value> {
    let primary = load(from: primaryURL, defaultValue: defaultValue)
    guard primaryURL != fallbackURL else { return primary }
    let primaryExists = FileManager.default.fileExists(atPath: primaryURL.path)
    guard !primaryExists || primary.notice != nil,
      FileManager.default.fileExists(atPath: fallbackURL.path)
    else { return primary }
    let fallback = load(from: fallbackURL, defaultValue: defaultValue)
    guard fallback.notice == nil else { return primary }
    guard primary.canSave else {
      return SavedEditLoad(
        value: fallback.value,
        notice:
          "The primary edit record could not be read. Edits were loaded from its path backup, but saving is paused to protect the primary record.",
        canSave: false, backupURL: primary.backupURL)
    }
    do {
      try save(fallback.value, to: primaryURL)
      return SavedEditLoad(
        value: fallback.value,
        notice: primaryExists
          ? "Saved edits were restored from the path backup after preserving the damaged primary record."
          : "Saved edits were restored from the path backup.",
        canSave: true, backupURL: primary.backupURL)
    } catch {
      return SavedEditLoad(
        value: fallback.value,
        notice:
          "Edits were loaded from the path backup, but the primary record could not be repaired. Saving is paused: \(error.localizedDescription)",
        canSave: false, backupURL: primary.backupURL)
    }
  }

  static func load<Value: Decodable>(from url: URL, defaultValue: Value) -> SavedEditLoad<Value> {
    let data: Data
    do {
      data = try Data(contentsOf: url)
    } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
      return SavedEditLoad(value: defaultValue, notice: nil, canSave: true, backupURL: nil)
    } catch {
      return SavedEditLoad(
        value: defaultValue,
        notice:
          "Saved edits could not be read. Editing is available, but saving is paused to protect the existing file: \(error.localizedDescription)",
        canSave: false, backupURL: nil)
    }
    if let saved = try? JSONDecoder().decode(Value.self, from: data) {
      return SavedEditLoad(value: saved, notice: nil, canSave: true, backupURL: nil)
    }
    let backupURL = url.deletingPathExtension()
      .appendingPathExtension("recovery-\(UUID().uuidString).json")
    do {
      try FileManager.default.copyItem(at: url, to: backupURL)
      return SavedEditLoad(
        value: defaultValue,
        notice:
          "Saved edits could not be decoded. The original record was backed up; new edits can be saved.",
        canSave: true, backupURL: backupURL)
    } catch {
      return SavedEditLoad(
        value: defaultValue,
        notice:
          "Saved edits could not be decoded or backed up. Saving is paused to protect the existing file: \(error.localizedDescription)",
        canSave: false, backupURL: nil)
    }
  }

  static func save<Value: Encodable>(_ value: Value, to url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode(value).write(to: url, options: .atomic)
  }
}

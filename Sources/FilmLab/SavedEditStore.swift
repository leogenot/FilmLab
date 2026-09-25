import Foundation

struct SavedEditLoad<Value> {
  let value: Value
  let notice: String?
  let canSave: Bool
  let backupURL: URL?
}

enum SavedEditStore {
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

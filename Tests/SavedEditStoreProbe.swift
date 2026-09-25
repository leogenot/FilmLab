import Foundation

private struct SampleEdits: Codable, Equatable {
  var exposure: Double
}

@main
struct SavedEditStoreProbe {
  static func main() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLabEditStoreProbe-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let editURL = directory.appendingPathComponent("photo.json")
    let defaults = SampleEdits(exposure: 0)

    let missing = SavedEditStore.load(from: editURL, defaultValue: defaults)
    precondition(missing.value == defaults && missing.notice == nil && missing.canSave)

    try SavedEditStore.save(SampleEdits(exposure: 1.25), to: editURL)
    let valid = SavedEditStore.load(from: editURL, defaultValue: defaults)
    precondition(valid.value.exposure == 1.25 && valid.notice == nil && valid.canSave)

    let damaged = Data("{unsupported edits".utf8)
    try damaged.write(to: editURL, options: .atomic)
    let recovered = SavedEditStore.load(from: editURL, defaultValue: defaults)
    precondition(
      recovered.value == defaults && recovered.notice != nil && recovered.canSave
        && recovered.backupURL != nil)
    let backups = try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil
    )
    .filter { $0.lastPathComponent.hasPrefix("photo.recovery-") }
    precondition(backups.count == 1)
    let backupData = try Data(contentsOf: backups[0])
    let originalData = try Data(contentsOf: editURL)
    precondition(backupData == damaged)
    precondition(originalData == damaged)

    try SavedEditStore.save(SampleEdits(exposure: 0.5), to: editURL)
    let replacement = SavedEditStore.load(from: editURL, defaultValue: defaults)
    precondition(replacement.value.exposure == 0.5)
    let retainedBackup = try Data(contentsOf: backups[0])
    precondition(retainedBackup == damaged)
    print("Saved edit recovery checks passed")
  }
}

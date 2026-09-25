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

    let primaryURL = directory.appendingPathComponent("identity.json")
    let pathURL = directory.appendingPathComponent("path.json")
    try SavedEditStore.save(SampleEdits(exposure: 1.75), to: pathURL)
    let fromPath = SavedEditStore.load(
      from: primaryURL, fallbackURL: pathURL, defaultValue: defaults)
    precondition(fromPath.value.exposure == 1.75 && fromPath.canSave)
    let migrated = SavedEditStore.load(from: primaryURL, defaultValue: defaults)
    precondition(migrated.value.exposure == 1.75)

    try SavedEditStore.save(SampleEdits(exposure: 2.25), to: primaryURL)
    let primaryWins = SavedEditStore.load(
      from: primaryURL, fallbackURL: pathURL, defaultValue: defaults)
    precondition(primaryWins.value.exposure == 2.25)

    let brokenPrimary = Data("{damaged identity record".utf8)
    try brokenPrimary.write(to: primaryURL, options: .atomic)
    let repaired = SavedEditStore.load(
      from: primaryURL, fallbackURL: pathURL, defaultValue: defaults)
    precondition(repaired.value.exposure == 1.75 && repaired.canSave)
    precondition(repaired.notice != nil && repaired.backupURL != nil)
    let preservedPrimary = try Data(contentsOf: repaired.backupURL!)
    precondition(preservedPrimary == brokenPrimary)
    let repairedPrimary = SavedEditStore.load(from: primaryURL, defaultValue: defaults)
    precondition(repairedPrimary.value.exposure == 1.75)

    try FileManager.default.removeItem(at: primaryURL)
    try FileManager.default.createDirectory(at: primaryURL, withIntermediateDirectories: true)
    let unreadablePrimary = SavedEditStore.load(
      from: primaryURL, fallbackURL: pathURL, defaultValue: defaults)
    precondition(unreadablePrimary.value.exposure == 1.75 && !unreadablePrimary.canSave)
    try FileManager.default.removeItem(at: primaryURL)
    print("Saved edit recovery checks passed")
  }
}

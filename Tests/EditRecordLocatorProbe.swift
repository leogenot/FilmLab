import Foundation

@main
struct EditRecordLocatorProbe {
  static func main() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLabEditLocatorProbe-\(UUID().uuidString)", isDirectory: true)
    let edits = root.appendingPathComponent("Edits", isDirectory: true)
    try FileManager.default.createDirectory(at: edits, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let original = root.appendingPathComponent("photo.jpg")
    try Data("source".utf8).write(to: original)
    let first = EditRecordLocator.locate(sourceURL: original, directory: edits)
    let originalGrainSeed = EditRecordLocator.grainSeed(for: original)
    precondition(first.primaryURL != first.pathURL)
    let storedLocation = try JSONEncoder().encode(first)
    let reopenedLocation = try JSONDecoder().decode(EditRecordLocation.self, from: storedLocation)
    precondition(reopenedLocation.primaryURL == first.primaryURL)
    precondition(reopenedLocation.pathURL == first.pathURL)
    try FileManager.default.createDirectory(
      at: first.primaryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("grade 1".utf8).write(to: first.primaryURL, options: .atomic)
    try Data("grade 1".utf8).write(to: first.pathURL, options: .atomic)

    let renamed = root.appendingPathComponent("renamed.jpg")
    try FileManager.default.moveItem(at: original, to: renamed)
    let afterRename = EditRecordLocator.locate(sourceURL: renamed, directory: edits)
    precondition(EditRecordLocator.grainSeed(for: renamed) == originalGrainSeed)
    precondition(afterRename.primaryURL == first.primaryURL)
    precondition(afterRename.pathURL != first.pathURL)
    let renamedGrade = try Data(contentsOf: afterRename.primaryURL)
    precondition(renamedGrade == Data("grade 1".utf8))
    try renamedGrade.write(to: afterRename.pathURL, options: .atomic)

    let copy = root.appendingPathComponent("copy.jpg")
    try FileManager.default.copyItem(at: renamed, to: copy)
    let copied = EditRecordLocator.locate(sourceURL: copy, directory: edits)
    precondition(EditRecordLocator.grainSeed(for: copy) != originalGrainSeed)
    precondition(copied.primaryURL != afterRename.primaryURL)
    try FileManager.default.removeItem(at: renamed)
    try FileManager.default.moveItem(at: copy, to: renamed)
    let replaced = EditRecordLocator.locate(sourceURL: renamed, directory: edits)
    precondition(replaced.primaryURL != afterRename.primaryURL)
    precondition(replaced.pathURL == afterRename.pathURL)
    let replacementGrade = try Data(contentsOf: replaced.primaryURL)
    precondition(replacementGrade == renamedGrade)

    let legacySource = root.appendingPathComponent("legacy.jpg")
    try Data("legacy source".utf8).write(to: legacySource)
    let legacy = EditRecordLocator.locate(sourceURL: legacySource, directory: edits)
    try Data("legacy grade".utf8).write(to: legacy.pathURL, options: .atomic)
    let migrated = EditRecordLocator.locate(sourceURL: legacySource, directory: edits)
    precondition(migrated.primaryURL == legacy.primaryURL)
    let stableGrade = try Data(contentsOf: migrated.primaryURL)
    let pathGrade = try Data(contentsOf: migrated.pathURL)
    precondition(stableGrade == Data("legacy grade".utf8))
    precondition(pathGrade == Data("legacy grade".utf8))

    print("Edit records follow renames, migrate legacy paths, and recover after file replacement")
  }
}

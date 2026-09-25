import Foundation

struct ReconnectedPhoto: Sendable {
  let oldPath: String
  let newURL: URL
}

struct PhotoLibraryReconnectResult: Sendable {
  let library: PhotoLibrary
  let relinked: [ReconnectedPhoto]
  let unresolved: Int
  let unavailableEdits: Int
  let failures: [String]
  let cancelled: Bool
}

/// Resolves moved originals from saved bookmarks without changing the persisted catalog.
/// The caller commits the returned library only if its starting snapshot is still current.
enum PhotoLibraryReconnect {
  static func run(
    _ startingLibrary: PhotoLibrary, in catalogID: UUID, editsDirectory: URL
  ) async -> PhotoLibraryReconnectResult {
    var library = startingLibrary
    let paths = library.catalogs.first(where: { $0.id == catalogID })?.photoPaths ?? []
    var relinked: [ReconnectedPhoto] = []
    var unresolved = 0
    var unavailableEdits = 0
    var failures: [String] = []
    var cancelled = false

    for path in paths where !FileManager.default.fileExists(atPath: path) {
      if Task.isCancelled {
        cancelled = true
        break
      }
      guard let replacement = library.resolvedMissingPhoto(at: path) else {
        unresolved += 1
        continue
      }
      let access = replacement.startAccessingSecurityScopedResource()
      do {
        let outcome = try PhotoEditRelinker.transferSavedEdits(
          from: URL(fileURLWithPath: path), to: replacement,
          directory: editsDirectory, as: PhotoEdits.self)
        if outcome == .unavailable { unavailableEdits += 1 }
        library.relinkPhoto(from: path, to: replacement)
        relinked.append(ReconnectedPhoto(oldPath: path, newURL: replacement))
      } catch {
        failures.append(URL(fileURLWithPath: path).lastPathComponent)
      }
      if access { replacement.stopAccessingSecurityScopedResource() }
      await Task.yield()
    }

    return PhotoLibraryReconnectResult(
      library: library, relinked: relinked, unresolved: unresolved,
      unavailableEdits: unavailableEdits, failures: failures, cancelled: cancelled)
  }
}

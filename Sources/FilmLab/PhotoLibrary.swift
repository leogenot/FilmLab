import Foundation

struct PhotoCatalog: Codable, Identifiable, Equatable {
  var id: UUID
  var name: String
  var photoPaths: [String]
}

enum LibrarySelection {
  static func range(in visiblePaths: [String], from anchor: String?, through target: String)
    -> Set<String>
  {
    guard let end = visiblePaths.firstIndex(of: target) else { return [] }
    guard let anchor, let start = visiblePaths.firstIndex(of: anchor) else {
      return [target]
    }
    return Set(visiblePaths[min(start, end)...max(start, end)])
  }
}

enum CatalogPhotoSelection {
  static func preferredPath(
    in availablePaths: [String], current: String?, remembered: String?
  ) -> String? {
    if let remembered, availablePaths.contains(remembered) { return remembered }
    if let current, availablePaths.contains(current) { return current }
    return availablePaths.first
  }
}

struct PhotoLibrary: Codable, Equatable {
  var catalogs: [PhotoCatalog]
  var selectedCatalogID: UUID
  var favoritePaths: Set<String>

  init(catalogs: [PhotoCatalog], selectedCatalogID: UUID, favoritePaths: Set<String> = []) {
    self.catalogs = catalogs
    self.selectedCatalogID = selectedCatalogID
    self.favoritePaths = favoritePaths
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    catalogs = try values.decode([PhotoCatalog].self, forKey: .catalogs)
    selectedCatalogID = try values.decode(UUID.self, forKey: .selectedCatalogID)
    favoritePaths = try values.decodeIfPresent(Set<String>.self, forKey: .favoritePaths) ?? []
  }

  static func empty() -> PhotoLibrary {
    let catalog = PhotoCatalog(id: UUID(), name: "My Photos", photoPaths: [])
    return PhotoLibrary(catalogs: [catalog], selectedCatalogID: catalog.id)
  }

  var selectedCatalog: PhotoCatalog? {
    catalogs.first { $0.id == selectedCatalogID }
  }

  func repaired() -> PhotoLibrary {
    var result = self
    if result.catalogs.isEmpty { return .empty() }
    var seenIDs = Set<UUID>()
    for index in result.catalogs.indices {
      while seenIDs.contains(result.catalogs[index].id) {
        result.catalogs[index].id = UUID()
      }
      seenIDs.insert(result.catalogs[index].id)
      if result.catalogs[index].name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        result.catalogs[index].name = "Untitled Catalog"
      }
      var seenPaths = Set<String>()
      result.catalogs[index].photoPaths.removeAll { !seenPaths.insert($0).inserted }
    }
    if result.selectedCatalog == nil {
      result.selectedCatalogID = result.catalogs[0].id
    }
    result.pruneOrphanedFavorites()
    return result
  }

  mutating func toggleFavorite(_ path: String) {
    guard catalogs.contains(where: { $0.photoPaths.contains(path) }) else { return }
    if !favoritePaths.insert(path).inserted { favoritePaths.remove(path) }
  }

  private mutating func pruneOrphanedFavorites() {
    let available = Set(catalogs.flatMap(\.photoPaths))
    favoritePaths.formIntersection(available)
  }

  mutating func createCatalog(named name: String) {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    let catalog = PhotoCatalog(id: UUID(), name: trimmed, photoPaths: [])
    catalogs.append(catalog)
    selectedCatalogID = catalog.id
  }

  mutating func renameCatalog(_ id: UUID, to name: String) {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let index = catalogs.firstIndex(where: { $0.id == id }) else { return }
    catalogs[index].name = trimmed
  }

  @discardableResult
  mutating func transferPhotos(_ paths: [String], to destinationID: UUID, removeFromSource: Bool)
    -> Int
  {
    guard destinationID != selectedCatalogID,
      let sourceIndex = catalogs.firstIndex(where: { $0.id == selectedCatalogID }),
      let destinationIndex = catalogs.firstIndex(where: { $0.id == destinationID })
    else { return 0 }
    let sourcePaths = Set(catalogs[sourceIndex].photoPaths)
    let selectedPaths = Set(paths).intersection(sourcePaths)
    guard !selectedPaths.isEmpty else { return 0 }
    var transferred = 0
    for path in catalogs[sourceIndex].photoPaths where selectedPaths.contains(path) {
      if !catalogs[destinationIndex].photoPaths.contains(path) {
        catalogs[destinationIndex].photoPaths.append(path)
        transferred += 1
      }
    }
    if removeFromSource {
      catalogs[sourceIndex].photoPaths.removeAll { selectedPaths.contains($0) }
      pruneOrphanedFavorites()
      return selectedPaths.count
    }
    return transferred
  }

  @discardableResult
  mutating func importPhotos(_ urls: [URL], into catalogID: UUID? = nil) -> Int {
    guard let index = catalogs.firstIndex(where: { $0.id == catalogID ?? selectedCatalogID }) else {
      return 0
    }
    var imported = 0
    var knownPaths = Set(catalogs[index].photoPaths)
    for url in urls {
      let path = url.standardizedFileURL.path
      if knownPaths.insert(path).inserted {
        catalogs[index].photoPaths.append(path)
        imported += 1
      }
    }
    return imported
  }

  mutating func removePhoto(_ path: String) {
    guard let index = catalogs.firstIndex(where: { $0.id == selectedCatalogID }) else { return }
    catalogs[index].photoPaths.removeAll { $0 == path }
    pruneOrphanedFavorites()
  }

  mutating func relinkPhoto(from oldPath: String, to url: URL) {
    let newPath = url.standardizedFileURL.path
    if favoritePaths.remove(oldPath) != nil { favoritePaths.insert(newPath) }
    for index in catalogs.indices {
      guard catalogs[index].photoPaths.contains(oldPath) else { continue }
      catalogs[index].photoPaths = catalogs[index].photoPaths.map {
        $0 == oldPath ? newPath : $0
      }
      var seen = Set<String>()
      catalogs[index].photoPaths.removeAll { !seen.insert($0).inserted }
    }
    pruneOrphanedFavorites()
  }

  func movedFolderRelinkCandidates(from oldPath: String, to selectedURL: URL) -> [(String, URL)] {
    let selected = (oldPath, selectedURL)
    let oldURL = URL(fileURLWithPath: oldPath).standardizedFileURL
    let newURL = selectedURL.standardizedFileURL
    let oldDirectory = oldURL.deletingLastPathComponent()
    let newDirectory = newURL.deletingLastPathComponent()
    guard oldURL.lastPathComponent == newURL.lastPathComponent,
      oldDirectory != newDirectory
    else { return [selected] }
    let paths = Set(catalogs.flatMap(\.photoPaths))
    let siblings = paths.sorted().compactMap { path -> (String, URL)? in
      guard path != oldPath else { return nil }
      let oldSibling = URL(fileURLWithPath: path).standardizedFileURL
      guard oldSibling.deletingLastPathComponent() == oldDirectory,
        !FileManager.default.fileExists(atPath: path)
      else { return nil }
      let newSibling = newDirectory.appendingPathComponent(oldSibling.lastPathComponent)
      var isDirectory: ObjCBool = false
      guard FileManager.default.fileExists(atPath: newSibling.path, isDirectory: &isDirectory),
        !isDirectory.boolValue
      else { return nil }
      return (path, newSibling)
    }
    return [selected] + siblings
  }

  mutating func deleteCatalog(_ id: UUID) {
    guard catalogs.count > 1 else { return }
    catalogs.removeAll { $0.id == id }
    if selectedCatalogID == id, let first = catalogs.first {
      selectedCatalogID = first.id
    }
    pruneOrphanedFavorites()
  }
}

enum PhotoLibraryStore {
  static func updating(
    _ library: PhotoLibrary, at url: URL, change: (inout PhotoLibrary) -> Void
  ) throws -> PhotoLibrary {
    var updated = library
    change(&updated)
    guard updated != library else { return library }
    try save(updated, to: url)
    return updated
  }

  static func loadSafely(from url: URL) -> SavedEditLoad<PhotoLibrary> {
    let loaded = SavedEditStore.load(from: url, defaultValue: PhotoLibrary.empty())
    guard loaded.canSave, loaded.notice == nil else { return loaded }
    let repaired = loaded.value.repaired()
    guard repaired != loaded.value else { return loaded }
    let backupURL = url.deletingPathExtension()
      .appendingPathExtension("recovery-\(UUID().uuidString).json")
    do {
      try FileManager.default.copyItem(at: url, to: backupURL)
    } catch {
      return SavedEditLoad(
        value: repaired,
        notice:
          "The library index needs repair, but its original could not be backed up. Saving is paused: \(error.localizedDescription)",
        canSave: false, backupURL: nil)
    }
    do {
      try save(repaired, to: url)
      return SavedEditLoad(
        value: repaired,
        notice: "The library index was repaired after preserving the original.",
        canSave: true, backupURL: backupURL)
    } catch {
      return SavedEditLoad(
        value: repaired,
        notice:
          "The library index was loaded, but its repair could not be saved. Saving is paused: \(error.localizedDescription)",
        canSave: false, backupURL: backupURL)
    }
  }

  static func load(from url: URL) -> PhotoLibrary {
    guard let data = try? Data(contentsOf: url),
      let library = try? JSONDecoder().decode(PhotoLibrary.self, from: data),
      !library.catalogs.isEmpty,
      library.selectedCatalog != nil
    else { return .empty() }
    return library
  }

  static func save(_ library: PhotoLibrary, to url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode(library).write(to: url, options: .atomic)
  }
}

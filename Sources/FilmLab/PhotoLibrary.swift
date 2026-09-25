import Foundation

struct PhotoCatalog: Codable, Identifiable, Equatable {
  var id: UUID
  var name: String
  var photoPaths: [String]
}

struct PhotoLibrary: Codable, Equatable {
  var catalogs: [PhotoCatalog]
  var selectedCatalogID: UUID

  static func empty() -> PhotoLibrary {
    let catalog = PhotoCatalog(id: UUID(), name: "My Photos", photoPaths: [])
    return PhotoLibrary(catalogs: [catalog], selectedCatalogID: catalog.id)
  }

  var selectedCatalog: PhotoCatalog? {
    catalogs.first { $0.id == selectedCatalogID }
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
      return selectedPaths.count
    }
    return transferred
  }

  mutating func importPhotos(_ urls: [URL]) {
    guard let index = catalogs.firstIndex(where: { $0.id == selectedCatalogID }) else { return }
    for url in urls {
      let path = url.standardizedFileURL.path
      if !catalogs[index].photoPaths.contains(path) {
        catalogs[index].photoPaths.append(path)
      }
    }
  }

  mutating func removePhoto(_ path: String) {
    guard let index = catalogs.firstIndex(where: { $0.id == selectedCatalogID }) else { return }
    catalogs[index].photoPaths.removeAll { $0 == path }
  }

  mutating func relinkPhoto(from oldPath: String, to url: URL) {
    let newPath = url.standardizedFileURL.path
    for index in catalogs.indices {
      guard catalogs[index].photoPaths.contains(oldPath) else { continue }
      catalogs[index].photoPaths = catalogs[index].photoPaths.map {
        $0 == oldPath ? newPath : $0
      }
      var seen = Set<String>()
      catalogs[index].photoPaths.removeAll { !seen.insert($0).inserted }
    }
  }

  mutating func deleteCatalog(_ id: UUID) {
    guard catalogs.count > 1 else { return }
    catalogs.removeAll { $0.id == id }
    if selectedCatalogID == id, let first = catalogs.first {
      selectedCatalogID = first.id
    }
  }
}

enum PhotoLibraryStore {
  static func loadSafely(from url: URL) -> SavedEditLoad<PhotoLibrary> {
    SavedEditStore.load(from: url, defaultValue: .empty())
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

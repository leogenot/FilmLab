import Foundation

enum CatalogPhotoMemory {
  private static let key = "FilmLab.lastPhotoByCatalog"

  static func load(from defaults: UserDefaults = .standard) -> [UUID: String] {
    let stored = defaults.dictionary(forKey: key) as? [String: String] ?? [:]
    var paths: [UUID: String] = [:]
    for (identifier, path) in stored {
      if let catalogID = UUID(uuidString: identifier) { paths[catalogID] = path }
    }
    return paths
  }

  static func save(_ paths: [UUID: String], to defaults: UserDefaults = .standard) {
    let stored = Dictionary(uniqueKeysWithValues: paths.map { ($0.key.uuidString, $0.value) })
    defaults.set(stored, forKey: key)
  }
}

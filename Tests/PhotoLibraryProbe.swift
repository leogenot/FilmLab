import Foundation

@main
struct PhotoLibraryProbe {
  static func main() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLab-library-probe-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("Library.json")
    var library = PhotoLibraryStore.load(from: url)
    precondition(library.catalogs.count == 1)
    let firstID = library.selectedCatalogID
    let first = URL(fileURLWithPath: "/tmp/a.ARW")
    library.importPhotos([first, first, URL(fileURLWithPath: "/tmp/b.jpg")])
    precondition(library.selectedCatalog?.photoPaths.count == 2)
    library.createCatalog(named: "  Portraits  ")
    precondition(library.selectedCatalog?.name == "Portraits")
    precondition(library.selectedCatalog?.photoPaths.isEmpty == true)
    library.importPhotos([first])
    try PhotoLibraryStore.save(library, to: url)
    var reopened = PhotoLibraryStore.load(from: url)
    precondition(reopened == library)
    reopened.removePhoto(first.standardizedFileURL.path)
    precondition(reopened.selectedCatalog?.photoPaths.isEmpty == true)
    reopened.selectedCatalogID = firstID
    precondition(reopened.selectedCatalog?.photoPaths.count == 2)
    reopened.deleteCatalog(library.selectedCatalogID)
    precondition(reopened.catalogs.count == 1)
    precondition(reopened.selectedCatalogID == firstID)
    reopened.deleteCatalog(firstID)
    precondition(reopened.catalogs.count == 1)
    precondition(FileManager.default.fileExists(atPath: url.path))
    try Data("{damaged library".utf8).write(to: url)
    let recovered = PhotoLibraryStore.loadSafely(from: url)
    precondition(recovered.notice != nil)
    precondition(recovered.canSave)
    precondition(recovered.backupURL != nil)
    let backupData = try Data(contentsOf: recovered.backupURL!)
    precondition(backupData == Data("{damaged library".utf8))
    print("Photo library checks passed")
  }
}

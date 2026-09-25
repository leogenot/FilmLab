import Foundation

private struct SampleGrade: Codable, Equatable {
  var exposure: Double
}

@main
struct PhotoLibraryProbe {
  static func main() throws {
    let visible = ["a", "b", "c", "d"]
    precondition(LibrarySelection.range(in: visible, from: "a", through: "c") == ["a", "b", "c"])
    precondition(LibrarySelection.range(in: visible, from: "d", through: "b") == ["b", "c", "d"])
    precondition(LibrarySelection.range(in: visible, from: "hidden", through: "c") == ["c"])
    precondition(LibrarySelection.range(in: visible, from: "b", through: "hidden").isEmpty)
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
    library.toggleFavorite(first.path)
    precondition(library.favoritePaths == [first.path])
    library.createCatalog(named: "  Portraits  ")
    precondition(library.selectedCatalog?.name == "Portraits")
    precondition(library.selectedCatalog?.photoPaths.isEmpty == true)
    library.importPhotos([first])
    let portraitsID = library.selectedCatalogID
    library.renameCatalog(portraitsID, to: "  People  ")
    precondition(library.selectedCatalog?.name == "People")
    library.renameCatalog(portraitsID, to: "  ")
    precondition(library.selectedCatalog?.name == "People")
    library.transferPhotos(
      [first.path, "/tmp/not-in-source.jpg"], to: firstID, removeFromSource: false)
    precondition(library.selectedCatalog?.photoPaths == [first.path])
    library.transferPhotos([first.path], to: firstID, removeFromSource: true)
    precondition(library.selectedCatalog?.photoPaths.isEmpty == true)
    library.transferPhotos([first.path], to: firstID, removeFromSource: true)
    library.importPhotos([first])
    try PhotoLibraryStore.save(library, to: url)
    var reopened = PhotoLibraryStore.load(from: url)
    precondition(reopened == library)
    let savedJSON = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
    var legacyJSON = savedJSON
    legacyJSON.removeValue(forKey: "favoritePaths")
    let legacyLibrary = try JSONDecoder().decode(
      PhotoLibrary.self, from: JSONSerialization.data(withJSONObject: legacyJSON))
    precondition(legacyLibrary.favoritePaths.isEmpty)
    reopened.removePhoto(first.standardizedFileURL.path)
    precondition(reopened.selectedCatalog?.photoPaths.isEmpty == true)
    precondition(reopened.favoritePaths.contains(first.path))
    reopened.selectedCatalogID = firstID
    precondition(reopened.selectedCatalog?.photoPaths.count == 2)
    reopened.deleteCatalog(library.selectedCatalogID)
    precondition(reopened.catalogs.count == 1)
    precondition(reopened.selectedCatalogID == firstID)
    reopened.deleteCatalog(firstID)
    precondition(reopened.catalogs.count == 1)
    let oldOriginal = directory.appendingPathComponent("old.jpg")
    let newOriginal = directory.appendingPathComponent("new.jpg")
    let edits = directory.appendingPathComponent("Edits")
    try Data("photo".utf8).write(to: oldOriginal)
    let oldLocation = EditRecordLocator.locate(sourceURL: oldOriginal, directory: edits)
    try SavedEditStore.save(SampleGrade(exposure: 1.25), to: oldLocation.pathURL)
    try FileManager.default.moveItem(at: oldOriginal, to: newOriginal)
    let transfer = try PhotoEditRelinker.transferSavedEdits(
      from: oldOriginal, to: newOriginal, directory: edits, as: SampleGrade.self)
    precondition(transfer == .transferred)
    let newLocation = EditRecordLocator.locate(sourceURL: newOriginal, directory: edits)
    let transferred = try JSONDecoder().decode(
      SampleGrade.self, from: Data(contentsOf: newLocation.primaryURL))
    precondition(transferred == SampleGrade(exposure: 1.25))
    let repeated = try PhotoEditRelinker.transferSavedEdits(
      from: oldOriginal, to: newOriginal, directory: edits, as: SampleGrade.self)
    precondition(repeated == .existing)
    reopened.importPhotos([oldOriginal, newOriginal])
    reopened.toggleFavorite(oldOriginal.standardizedFileURL.path)
    reopened.relinkPhoto(from: oldOriginal.standardizedFileURL.path, to: newOriginal)
    let paths = reopened.selectedCatalog?.photoPaths ?? []
    precondition(!paths.contains(oldOriginal.standardizedFileURL.path))
    precondition(paths.filter { $0 == newOriginal.standardizedFileURL.path }.count == 1)
    precondition(reopened.favoritePaths.contains(newOriginal.standardizedFileURL.path))
    precondition(!reopened.favoritePaths.contains(oldOriginal.standardizedFileURL.path))
    reopened.removePhoto(newOriginal.standardizedFileURL.path)
    precondition(!reopened.favoritePaths.contains(newOriginal.standardizedFileURL.path))
    let oldFolder = directory.appendingPathComponent("old-folder")
    let newFolder = directory.appendingPathComponent("new-folder")
    try FileManager.default.createDirectory(at: oldFolder, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: newFolder, withIntermediateDirectories: true)
    let oldRAW = oldFolder.appendingPathComponent("scene.ARW")
    let oldJPEG = oldFolder.appendingPathComponent("scene.jpg")
    let newRAW = newFolder.appendingPathComponent("scene.ARW")
    let newJPEG = newFolder.appendingPathComponent("scene.jpg")
    try Data("raw".utf8).write(to: oldRAW)
    try Data("jpeg".utf8).write(to: oldJPEG)
    var movedLibrary = PhotoLibrary.empty()
    movedLibrary.importPhotos([oldRAW, oldJPEG])
    movedLibrary.toggleFavorite(oldRAW.path)
    for (oldURL, grade) in [(oldRAW, 0.6), (oldJPEG, -0.4)] {
      let location = EditRecordLocator.locate(sourceURL: oldURL, directory: edits)
      try SavedEditStore.save(SampleGrade(exposure: grade), to: location.pathURL)
    }
    try FileManager.default.copyItem(at: oldRAW, to: newRAW)
    try FileManager.default.copyItem(at: oldJPEG, to: newJPEG)
    try FileManager.default.removeItem(at: oldFolder)
    let candidates = movedLibrary.movedFolderRelinkCandidates(from: oldRAW.path, to: newRAW)
    precondition(candidates.count == 2)
    precondition(candidates[0].0 == oldRAW.path && candidates[0].1 == newRAW)
    precondition(candidates[1].0 == oldJPEG.path && candidates[1].1 == newJPEG)
    for (oldPath, newURL) in candidates {
      let outcome = try PhotoEditRelinker.transferSavedEdits(
        from: URL(fileURLWithPath: oldPath), to: newURL, directory: edits,
        as: SampleGrade.self)
      precondition(outcome == .transferred)
      movedLibrary.relinkPhoto(from: oldPath, to: newURL)
    }
    precondition(movedLibrary.selectedCatalog?.photoPaths == [newRAW.path, newJPEG.path])
    precondition(movedLibrary.favoritePaths == [newRAW.path])
    for (newURL, grade) in [(newRAW, 0.6), (newJPEG, -0.4)] {
      let location = EditRecordLocator.locate(sourceURL: newURL, directory: edits)
      let saved = try JSONDecoder().decode(
        SampleGrade.self, from: Data(contentsOf: location.primaryURL))
      precondition(saved.exposure == grade)
    }
    precondition(
      movedLibrary.movedFolderRelinkCandidates(from: oldRAW.path, to: newJPEG).count == 1)
    precondition(FileManager.default.fileExists(atPath: url.path))
    try PhotoLibraryStore.save(library, to: url)
    try Data("{damaged library".utf8).write(to: url)
    let recovered = PhotoLibraryStore.loadSafely(from: url)
    precondition(recovered.notice != nil)
    precondition(recovered.canSave)
    precondition(recovered.value == library)
    precondition(recovered.backupURL != nil)
    let backupData = try Data(contentsOf: recovered.backupURL!)
    precondition(backupData == Data("{damaged library".utf8))
    let semanticURL = directory.appendingPathComponent("SemanticLibrary.json")
    let sharedID = UUID()
    let broken = PhotoLibrary(
      catalogs: [
        PhotoCatalog(id: sharedID, name: "Keep", photoPaths: [first.path, first.path]),
        PhotoCatalog(id: sharedID, name: " ", photoPaths: ["/tmp/second.jpg"]),
      ], selectedCatalogID: UUID())
    try PhotoLibraryStore.save(broken, to: semanticURL)
    let semanticOriginal = try Data(contentsOf: semanticURL)
    let repaired = PhotoLibraryStore.loadSafely(from: semanticURL)
    precondition(repaired.canSave && repaired.notice != nil && repaired.backupURL != nil)
    precondition(repaired.value.catalogs.count == 2)
    precondition(repaired.value.catalogs[0].photoPaths == [first.path])
    precondition(repaired.value.catalogs[1].name == "Untitled Catalog")
    precondition(repaired.value.catalogs[0].id != repaired.value.catalogs[1].id)
    precondition(repaired.value.selectedCatalogID == sharedID)
    let preservedSemantic = try Data(contentsOf: repaired.backupURL!)
    precondition(preservedSemantic == semanticOriginal)
    precondition(PhotoLibraryStore.load(from: semanticURL) == repaired.value)
    let emptyURL = directory.appendingPathComponent("EmptyLibrary.json")
    try PhotoLibraryStore.save(PhotoLibrary(catalogs: [], selectedCatalogID: UUID()), to: emptyURL)
    let emptyRepaired = PhotoLibraryStore.loadSafely(from: emptyURL)
    precondition(emptyRepaired.value.catalogs.count == 1 && !emptyRepaired.canSave)
    print("Photo library checks passed")
  }
}

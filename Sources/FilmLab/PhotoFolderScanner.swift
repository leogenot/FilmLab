import Foundation
import UniformTypeIdentifiers

enum PhotoFolderScanError: LocalizedError {
  case couldNotOpen

  var errorDescription: String? {
    "Could not read the selected photo folder."
  }
}

actor PhotoFolderScanner {
  func scan(_ folder: URL) throws -> [URL] {
    var enumerationError: Error?
    guard
      let enumerator = FileManager.default.enumerator(
        at: folder,
        includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
        options: [.skipsHiddenFiles, .skipsPackageDescendants],
        errorHandler: { _, error in
          enumerationError = error
          return false
        }
      )
    else { throw PhotoFolderScanError.couldNotOpen }

    var photos: [URL] = []
    for case let url as URL in enumerator {
      try Task.checkCancellation()
      let properties = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
      guard properties.isRegularFile == true, properties.isSymbolicLink != true,
        let type = UTType(filenameExtension: url.pathExtension),
        type.conforms(to: .image) || type.conforms(to: .rawImage),
        PhotoFileSupport.hasImageHeader(url)
      else { continue }
      photos.append(url.standardizedFileURL)
    }
    if let enumerationError { throw enumerationError }
    return photos.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
  }
}

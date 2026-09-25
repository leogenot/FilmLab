import Foundation
import UniformTypeIdentifiers

struct PhotoImportSelection: Sendable {
  var photos: [URL] = []
  var folders: [URL] = []
  var ignoredCount = 0

  init(urls: [URL]) {
    var seen = Set<String>()
    for input in urls {
      let url = input.standardizedFileURL
      guard url.isFileURL, seen.insert(url.path).inserted,
        let values = try? url.resourceValues(forKeys: [
          .isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey,
        ]), values.isSymbolicLink != true
      else {
        ignoredCount += 1
        continue
      }
      if values.isDirectory == true {
        folders.append(url)
      } else if values.isRegularFile == true,
        let type = UTType(filenameExtension: url.pathExtension),
        type.conforms(to: .image) || type.conforms(to: .rawImage),
        PhotoFileSupport.hasImageHeader(url)
      {
        photos.append(url)
      } else {
        ignoredCount += 1
      }
    }
  }
}

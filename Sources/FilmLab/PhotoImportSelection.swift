import Foundation
import UniformTypeIdentifiers

struct PhotoImportSelection: Sendable {
  var photos: [URL] = []
  var folders: [URL] = []
  var ignoredCount = 0

  private init() {}

  init(urls: [URL]) {
    self = Self.classify(urls: urls, isCancelled: { false }) ?? Self()
  }

  static func cancellable(
    urls: [URL], isCancelled: () -> Bool = { Task.isCancelled }
  ) -> Self? {
    classify(urls: urls, isCancelled: isCancelled)
  }

  private static func classify(urls: [URL], isCancelled: () -> Bool) -> Self? {
    var selection = Self()
    var seen = Set<String>()
    for input in urls {
      guard !isCancelled() else { return nil }
      let url = input.standardizedFileURL
      guard url.isFileURL, seen.insert(url.path).inserted,
        let values = try? url.resourceValues(forKeys: [
          .isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey,
        ]), values.isSymbolicLink != true
      else {
        selection.ignoredCount += 1
        continue
      }
      if values.isDirectory == true {
        selection.folders.append(url)
      } else if values.isRegularFile == true,
        let type = UTType(filenameExtension: url.pathExtension),
        type.conforms(to: .image) || type.conforms(to: .rawImage),
        PhotoFileSupport.hasImageHeader(url)
      {
        selection.photos.append(url)
      } else {
        selection.ignoredCount += 1
      }
    }
    return isCancelled() ? nil : selection
  }
}

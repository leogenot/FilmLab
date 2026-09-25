import Foundation

enum PhotoEditRelinkResult: Equatable {
  case transferred
  case existing
  case unavailable
}

enum PhotoEditRelinker {
  static func transferSavedEdits<Value: Codable>(
    from oldURL: URL, to newURL: URL, directory: URL, as type: Value.Type
  ) throws -> PhotoEditRelinkResult {
    let target = EditRecordLocator.locate(sourceURL: newURL, directory: directory)
    if FileManager.default.fileExists(atPath: target.primaryURL.path)
      || FileManager.default.fileExists(atPath: target.pathURL.path)
    {
      return .existing
    }
    let previous = EditRecordLocator.locate(sourceURL: oldURL, directory: directory)
    guard let data = try? Data(contentsOf: previous.pathURL),
      let edits = try? JSONDecoder().decode(type, from: data)
    else { return .unavailable }
    try SavedEditStore.save(edits, to: target.pathURL)
    if target.primaryURL != target.pathURL {
      try SavedEditStore.save(edits, to: target.primaryURL)
    }
    return .transferred
  }
}

import Foundation

struct LookFile<Settings: Codable>: Codable {
  let formatVersion: Int
  let settings: Settings

  init(settings: Settings) {
    formatVersion = 1
    self.settings = settings
  }

  func write(to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(self).write(to: url, options: .atomic)
  }

  static func read(from url: URL) throws -> Settings {
    let archive = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    guard archive.formatVersion == 1 else { throw LookFileError.unsupportedVersion }
    return archive.settings
  }
}

enum LookFileError: LocalizedError {
  case unsupportedVersion

  var errorDescription: String? {
    "This look file uses a version FilmLab cannot read."
  }
}

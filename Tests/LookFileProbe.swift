import Foundation

private struct SampleSettings: Codable, Equatable {
  var stock: Int
  var exposure: Double
}

@main
struct LookFileProbe {
  static func main() throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("FilmLabLookProbe-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let settings = SampleSettings(stock: 2, exposure: 1.25)
    try LookFile(settings: settings).write(to: url)
    let restored: SampleSettings = try LookFile.read(from: url)
    precondition(restored == settings)

    try Data(#"{"formatVersion":2,"settings":{"stock":2,"exposure":1.25}}"#.utf8)
      .write(to: url, options: .atomic)
    do {
      let _: SampleSettings = try LookFile.read(from: url)
      preconditionFailure("Unsupported look version was accepted")
    } catch LookFileError.unsupportedVersion {}
    print("Portable look file checks passed")
  }
}

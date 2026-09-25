import Foundation
import XCTest

@testable import FilmLab

final class CatalogPhotoMemoryTests: XCTestCase {
  func testPerCatalogSelectionSurvivesReloadAndCanBeCleared() throws {
    let suite = "FilmLab-catalog-memory-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let first = UUID()
    let second = UUID()
    let paths = [first: "/tmp/first.ARW", second: "/tmp/second.jpg"]

    CatalogPhotoMemory.save(paths, to: defaults)
    XCTAssertEqual(CatalogPhotoMemory.load(from: defaults), paths)

    CatalogPhotoMemory.save([:], to: defaults)
    XCTAssertTrue(CatalogPhotoMemory.load(from: defaults).isEmpty)
  }
}

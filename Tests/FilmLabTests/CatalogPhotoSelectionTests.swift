import XCTest

@testable import FilmLab

final class CatalogPhotoSelectionTests: XCTestCase {
  func testKeepsCurrentPhotoWhenCatalogHasNoRememberedPhoto() {
    XCTAssertEqual(
      CatalogPhotoSelection.preferredPath(
        in: ["first.ARW", "second.jpg"], current: "second.jpg", remembered: nil),
      "second.jpg")
  }

  func testReturnsToRememberedPhotoWhenSwitchingCatalogs() {
    XCTAssertEqual(
      CatalogPhotoSelection.preferredPath(
        in: ["first.ARW", "second.jpg"], current: "first.ARW", remembered: "second.jpg"),
      "second.jpg")
  }

  func testUsesFirstAvailablePhotoOrClearsEmptyCatalog() {
    XCTAssertEqual(
      CatalogPhotoSelection.preferredPath(
        in: ["first.ARW"], current: "missing.jpg", remembered: "missing.ARW"),
      "first.ARW")
    XCTAssertNil(
      CatalogPhotoSelection.preferredPath(
        in: [], current: "elsewhere.jpg", remembered: "elsewhere.jpg"))
  }
}

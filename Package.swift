// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "FilmLab",
  platforms: [.macOS(.v15)],
  products: [.executable(name: "FilmLab", targets: ["FilmLab"])],
  targets: [
    .executableTarget(name: "FilmLab"),
    .testTarget(name: "FilmLabTests", dependencies: ["FilmLab"]),
  ]
)

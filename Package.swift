// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Penny",
  platforms: [.iOS(.v17), .macOS(.v14), .watchOS(.v10), .tvOS(.v17)],
  products: [.library(name: "PennyCore", targets: ["PennyCore"])],
  targets: [
    .target(name: "PennyCore"),
    .testTarget(name: "PennyCoreTests", dependencies: ["PennyCore"]),
  ]
)

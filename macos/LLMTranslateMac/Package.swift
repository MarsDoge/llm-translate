// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "LLMTranslateMac",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "LLMTranslateMac", targets: ["LLMTranslateMac"])
  ],
  targets: [
    .executableTarget(name: "LLMTranslateMac")
  ],
  swiftLanguageVersions: [.v5]
)

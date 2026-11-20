// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MarkdownEditor",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "CommonMark"),
        .testTarget(name: "CommonMarkTests", dependencies: ["CommonMark"]),
    ],
    swiftLanguageModes: [.v5]
)

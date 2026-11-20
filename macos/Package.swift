// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MarkdownEditor",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "CommonMark"),
        .target(name: "MarkdownEditorCore", dependencies: ["CommonMark"]),
        .target(name: "MarkdownEditorPlugins", dependencies: ["CommonMark", "MarkdownEditorCore"]),
        .target(name: "TestSupport", path: "Tests/TestSupport"),
        .testTarget(name: "CommonMarkTests", dependencies: ["CommonMark", "TestSupport"]),
        .testTarget(name: "MarkdownEditorCoreTests", dependencies: ["MarkdownEditorCore", "CommonMark", "TestSupport"]),
        .testTarget(name: "MarkdownEditorPluginsTests", dependencies: ["MarkdownEditorPlugins", "MarkdownEditorCore", "CommonMark", "TestSupport"]),
    ],
    swiftLanguageModes: [.v5]
)

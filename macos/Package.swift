// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MarkdownEditor",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "MarkdownEditor", targets: ["MarkdownEditor"])],
    targets: [
        .target(name: "CommonMark"),
        .target(name: "MarkdownEditorCore", dependencies: ["CommonMark"]),
        .target(name: "MarkdownEditorPlugins", dependencies: ["CommonMark", "MarkdownEditorCore"]),
        .target(name: "MarkdownEditorUI", dependencies: ["MarkdownEditorCore", "MarkdownEditorPlugins"]),
        .executableTarget(name: "MarkdownEditor", dependencies: ["MarkdownEditorUI"]),
        .target(name: "TestSupport", path: "Tests/TestSupport"),
        .testTarget(name: "CommonMarkTests", dependencies: ["CommonMark", "TestSupport"]),
        .testTarget(name: "MarkdownEditorCoreTests", dependencies: ["MarkdownEditorCore", "CommonMark", "TestSupport"]),
        .testTarget(name: "MarkdownEditorUITests", dependencies: ["MarkdownEditorUI", "MarkdownEditorPlugins", "MarkdownEditorCore", "TestSupport"]),
        .testTarget(name: "MarkdownEditorPluginsTests", dependencies: ["MarkdownEditorPlugins", "MarkdownEditorCore", "CommonMark", "TestSupport"]),
    ],
    swiftLanguageModes: [.v5]
)

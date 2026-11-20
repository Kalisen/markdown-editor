import CommonMark
import Foundation
@testable import MarkdownEditorCore

struct FakePlugin: MarkdownPlugin {
    let id: String
    var previewAssets: [PreviewAsset] = []
    var configure: (MarkdownPipelineBuilder) throws -> Void = { _ in }

    var name: String { id }
    var version: PluginVersion { PluginVersion(1, 0) }

    func configurePipeline(_ builder: MarkdownPipelineBuilder) throws { try configure(builder) }
}

/// Strikethrough with `~~`, standing in for a real syntax extension.
let strikethroughDelimiter = EmphasisDelimiter(character: UInt8(ascii: "~"), allowsIntraword: false, maximumRunLength: 2, matchesWholeRuns: true) { _ in "del" }

struct ProbingPlugin: MarkdownPlugin, DocumentFeatureProbe {
    let id: String
    let probe: (Document) -> Bool

    var name: String { id }
    var version: PluginVersion { PluginVersion(1, 0) }
    var previewAssets: [PreviewAsset] { [] }

    func configurePipeline(_ builder: MarkdownPipelineBuilder) { builder.addEmphasisDelimiter(strikethroughDelimiter) }

    func isUsed(by document: Document) -> Bool { probe(document) }
}

struct TestError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

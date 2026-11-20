import CommonMark
import MarkdownEditorCore

/// GFM strikethrough: `~~text~~` and (as on GitHub.com) `~text~` render as `<del>`.
public struct StrikethroughPlugin: MarkdownPlugin, DocumentFeatureProbe {
    public static let pluginID = "strikethrough"
    static let tilde = UInt8(ascii: "~")

    public init() {}

    public var id: String { Self.pluginID }
    public var name: String { "Strikethrough (GFM)" }
    public var version: PluginVersion { PluginVersion(1, 0, 0) }
    public var previewAssets: [PreviewAsset] { [] }

    public func isUsed(by document: Document) -> Bool {
        document.hasDescendant(ofType: Emphasis.self) { $0.delimiter == Self.tilde }
    }

    public func configurePipeline(_ builder: MarkdownPipelineBuilder) {
        builder.addEmphasisDelimiter(EmphasisDelimiter(
            character: Self.tilde, allowsIntraword: false, maximumRunLength: 2, matchesWholeRuns: true) { _ in "del" })
    }
}

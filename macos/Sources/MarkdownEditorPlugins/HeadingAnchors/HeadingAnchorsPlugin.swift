import CommonMark
import MarkdownEditorCore

/// GitHub-compatible heading ids so `#section` links work, plus a link icon shown on hover.
public struct HeadingAnchorsPlugin: MarkdownPlugin, DocumentFeatureProbe {
    public static let pluginID = "heading-anchors"
    public static let scriptPath = "assets/heading-anchors.js"
    public static let stylesheetPath = "assets/heading-anchors.css"

    public init() {}

    public var id: String { Self.pluginID }
    public var name: String { "Heading anchors" }
    public var version: PluginVersion { PluginVersion(1, 0, 0) }
    public var previewAssets: [PreviewAsset] { [.stylesheet(Self.stylesheetPath), .script(Self.scriptPath)] }

    public func isUsed(by document: Document) -> Bool {
        document.hasDescendant(ofType: Heading.self)
    }

    public func configurePipeline(_ builder: MarkdownPipelineBuilder) {
        HeadingIdentifiers.register(in: builder)
    }
}

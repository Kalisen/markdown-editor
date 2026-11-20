import CommonMark
import MarkdownEditorCore

/// Renders ```` ```dot ```` / ```` ```graphviz ```` fenced blocks as diagrams with a bundled Graphviz (Viz.js, WebAssembly).
/// Markdown rendering is unchanged; diagrams are drawn in the preview.
public struct GraphvizPlugin: MarkdownPlugin, DocumentFeatureProbe {
    public static let pluginID = "graphviz"
    public static let vizVersion = "3.31.0"
    public static let vizScriptPath = "assets/vendor/viz-\(vizVersion)/viz-global.js"
    public static let bootstrapScriptPath = "assets/graphviz.js"
    public static let stylesheetPath = "assets/graphviz.css"
    public static let languages = ["dot", "graphviz"]

    public init() {}

    public var id: String { Self.pluginID }
    public var name: String { "Graphviz diagrams" }
    public var version: PluginVersion { PluginVersion(1, 0, 0) }
    public var previewAssets: [PreviewAsset] {
        [.stylesheet(Self.stylesheetPath), .script(Self.vizScriptPath), .script(Self.bootstrapScriptPath)]
    }

    public func isUsed(by document: Document) -> Bool {
        document.hasDescendant(ofType: CodeBlock.self) { $0.isFenced && Self.languages.contains($0.language) }
    }

    public func configurePipeline(_ builder: MarkdownPipelineBuilder) {}
}

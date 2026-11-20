import CommonMark
import MarkdownEditorCore

/// Highlights fenced code blocks that declare a language (```` ```swift ````), using a bundled highlight.js with
/// GitHub's light/dark colours. Rendering is unchanged: CommonMark already emits `class="language-x"`;
/// highlighting happens in the preview.
public struct SyntaxHighlightingPlugin: MarkdownPlugin, DocumentFeatureProbe {
    public static let pluginID = "syntax-highlighting"
    public static let highlightJSVersion = "11.12.0"
    public static let vendorFolder = "assets/vendor/highlightjs-\(highlightJSVersion)"
    public static let highlightJSPath = "\(vendorFolder)/highlight.min.js"
    public static let lightThemePath = "\(vendorFolder)/github.min.css"
    public static let darkThemePath = "\(vendorFolder)/github-dark.min.css"
    public static let bootstrapScriptPath = "assets/syntax-highlighting.js"
    public static let stylesheetPath = "assets/syntax-highlighting.css"

    /// Fence languages drawn by other plugins rather than highlighted (kept in sync with the script).
    public static let renderedByOtherPlugins: Set<String> = ["math", "mermaid", "dot", "graphviz"]

    public init() {}

    public var id: String { Self.pluginID }
    public var name: String { "Syntax highlighting" }
    public var version: PluginVersion { PluginVersion(1, 0, 0) }

    /// The theme stylesheet (light or dark) is added by the bootstrap script, which knows the preview theme.
    public var previewAssets: [PreviewAsset] {
        [.stylesheet(Self.stylesheetPath), .script(Self.highlightJSPath), .script(Self.bootstrapScriptPath)]
    }

    public func isUsed(by document: Document) -> Bool {
        document.hasDescendant(ofType: CodeBlock.self) {
            $0.isFenced && !$0.language.isEmpty && !Self.renderedByOtherPlugins.contains($0.language)
        }
    }

    public func configurePipeline(_ builder: MarkdownPipelineBuilder) {}
}

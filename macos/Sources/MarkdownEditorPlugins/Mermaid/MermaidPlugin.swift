import CommonMark
import MarkdownEditorCore

/// Renders ```` ```mermaid ```` fenced code blocks as diagrams using a bundled Mermaid build.
public struct MermaidPlugin: MarkdownPlugin, DocumentFeatureProbe {
    public static let pluginID = "mermaid"
    public static let mermaidVersion = "12.3.0"
    public static let mermaidScriptPath = "assets/vendor/mermaid-\(mermaidVersion)/mermaid.min.js"
    public static let bootstrapScriptPath = "assets/mermaid-preview.js"
    public static let stylesheetPath = "assets/mermaid-preview.css"
    public static let infoString = "mermaid"
    public static let diagramClass = "mermaid-diagram"
    public static let sourceClass = "mermaid-source"

    public init() {}

    public var id: String { Self.pluginID }
    public var name: String { "Mermaid diagrams" }
    public var version: PluginVersion { PluginVersion(1, 0, 0) }

    /// Mermaid must load before the bootstrap script that uses it.
    public var previewAssets: [PreviewAsset] {
        [.stylesheet(Self.stylesheetPath), .script(Self.mermaidScriptPath), .script(Self.bootstrapScriptPath)]
    }

    public func isUsed(by document: Document) -> Bool {
        document.hasDescendant(ofType: CodeBlock.self, where: Self.isMermaid)
    }

    static func isMermaid(_ block: CodeBlock) -> Bool {
        block.isFenced && block.language == infoString
    }

    /// Mermaid blocks render as `<div class="mermaid-diagram"><pre class="mermaid-source">…</pre></div>`
    /// (the preview script replaces the source with an SVG); every other code block renders as usual.
    public func configurePipeline(_ builder: MarkdownPipelineBuilder) {
        builder.wrapRendering(of: CodeBlock.self) { block, renderer, original in
            guard Self.isMermaid(block) else {
                original()
                return
            }
            renderer.ensureLine()
            renderer.write("<div class=\"\(Self.diagramClass)\"")
            renderer.writeAttributes(of: block)
            renderer.write("><pre class=\"\(Self.sourceClass)\">")
            renderer.writeEscaped(block.literal)
            renderer.write("</pre></div>\n")
        }
    }
}

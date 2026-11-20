import CommonMark

/// Rendered HTML and the plugins whose `DocumentFeatureProbe` reports they apply to the document.
public struct RenderResult {
    public let html: String
    public let usedPlugins: [MarkdownPlugin]
}

/// Converts Markdown to HTML. The base pipeline is strict CommonMark; plugins add extensions.
/// A plugin throwing while configuring the pipeline is excluded and reported in `failures`.
public final class MarkdownRenderer {
    private static let logger = Diagnostics.logger(category: "Rendering")

    private let pipeline: MarkdownPipeline

    /// Plugins configured into the pipeline.
    public let activePlugins: [MarkdownPlugin]

    public let failures: [PluginLoadFailure]

    public init(plugins: [MarkdownPlugin] = []) {
        var failures: [PluginLoadFailure] = []
        var active: [MarkdownPlugin] = []
        let builder = MarkdownPipelineBuilder()
        for plugin in plugins {
            do {
                // Configure a probe builder first so a failing plugin cannot leave the real one half-configured.
                try plugin.configurePipeline(MarkdownPipelineBuilder())
                try plugin.configurePipeline(builder)
                active.append(plugin)
            } catch {
                Self.logger.warning("Plugin \(plugin.id, privacy: .public) skipped: \(error.localizedDescription, privacy: .public)")
                failures.append(PluginLoadFailure(source: plugin.id, reason: error.localizedDescription))
            }
        }
        pipeline = builder.build()
        activePlugins = active
        self.failures = failures
    }

    public func render(_ markdown: String) -> String {
        renderDocument(markdown).html
    }

    /// Parses once and uses the same syntax tree for the HTML and for plugin usage detection.
    /// - Parameter annotateSourceLines: tags blocks with their source lines (see `SourceLineAnnotator`), for the preview.
    public func renderDocument(_ markdown: String, annotateSourceLines: Bool = false) -> RenderResult {
        let document = pipeline.parse(markdown)
        if annotateSourceLines { SourceLineAnnotator.annotate(document) }
        let used = activePlugins.filter { ($0 as? DocumentFeatureProbe)?.isUsed(by: document) ?? false }
        return RenderResult(html: pipeline.renderHTML(document), usedPlugins: used)
    }
}

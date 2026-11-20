import MarkdownEditorCore

/// The plugins compiled into the app, in the order they are configured into the Markdown pipeline.
public enum BundledPlugins {
    public static let all: [MarkdownPlugin] = [
        AlertsPlugin(), AutolinksPlugin(), EmojiPlugin(), FootnotesPlugin(), FrontMatterPlugin(), GraphvizPlugin(),
        HeadingAnchorsPlugin(), ImagesPlugin(), MathPlugin(), MermaidPlugin(), StrikethroughPlugin(),
        SyntaxHighlightingPlugin(), TablesPlugin(), TagFilterPlugin(), TaskListsPlugin(), TocPlugin(), WikiLinksPlugin(),
    ]
}

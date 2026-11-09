using Markdig.Syntax;
using Markdig;
using Markdig.Renderers;
using MarkdownEditor.Plugins.Abstractions;
using MarkdownEditor.Plugins.Abstractions.Preview;

namespace MarkdownEditor.Plugin.Tables;

/// <summary>GitHub Flavored Markdown tables (GFM spec 0.29, section 4.10), with column alignment.</summary>
public sealed class TablesPlugin : IMarkdownPlugin, IDocumentFeatureProbe
{
    public const string PluginId = "tables";
    public const string StylesheetPath = "assets/tables.css";

    public string Id => PluginId;

    public string Name => "Tables (GFM)";

    public Version Version => new(1, 1, 0);

    public IReadOnlyList<PreviewAsset> PreviewAssets { get; } = [PreviewAsset.Stylesheet(StylesheetPath)];

    public bool IsUsedBy(MarkdownDocument document) =>
        document.Descendants<GfmTable>().Any();

    public void ConfigurePipeline(MarkdownPipelineBuilder builder) =>
        builder.Extensions.AddIfNotAlready<GfmTableExtension>();
}

internal sealed class GfmTableExtension : IMarkdownExtension
{
    public void Setup(MarkdownPipelineBuilder pipeline)
    {
        // Before the thematic break / list parsers so delimiter rows such as "-|-" are seen first.
        if (!pipeline.BlockParsers.Contains<GfmTableParser>()) pipeline.BlockParsers.Insert(0, new GfmTableParser());
    }

    public void Setup(MarkdownPipeline pipeline, IMarkdownRenderer renderer)
    {
        if (renderer is HtmlRenderer html && !html.ObjectRenderers.Contains<GfmTableRenderer>())
            html.ObjectRenderers.Add(new GfmTableRenderer());
    }
}

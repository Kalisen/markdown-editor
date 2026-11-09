using Markdig.Syntax;
using Markdig;
using Markdig.Extensions.AutoIdentifiers;
using Markdig.Renderers;
using MarkdownEditor.Plugins.Abstractions;
using MarkdownEditor.Plugins.Abstractions.Preview;

namespace MarkdownEditor.Plugin.Toc;

/// <summary>
/// Table of contents: a line containing only <c>[TOC]</c> or <c>[[_TOC_]]</c> renders as a nested list of
/// links to the document's headings.
/// </summary>
public sealed class TocPlugin : IMarkdownPlugin, IDocumentFeatureProbe
{
    public const string PluginId = "toc";
    public const string StylesheetPath = "assets/toc.css";

    public string Id => PluginId;

    public string Name => "Table of contents";

    public Version Version => new(1, 0, 0);

    public IReadOnlyList<PreviewAsset> PreviewAssets { get; } = [PreviewAsset.Stylesheet(StylesheetPath)];

    public bool IsUsedBy(MarkdownDocument document) =>
        document.Descendants<TocBlock>().Any();

    public void ConfigurePipeline(MarkdownPipelineBuilder builder)
    {
        // Same id algorithm as the heading-anchors plugin; the first registration wins, so both agree.
        builder.UseAutoIdentifiers(AutoIdentifierOptions.GitHub);
        builder.Extensions.AddIfNotAlready<TocExtension>();
    }
}

internal sealed class TocExtension : IMarkdownExtension
{
    public void Setup(MarkdownPipelineBuilder pipeline)
    {
        if (!pipeline.BlockParsers.Contains<TocBlockParser>()) pipeline.BlockParsers.Insert(0, new TocBlockParser());
    }

    public void Setup(MarkdownPipeline pipeline, IMarkdownRenderer renderer)
    {
        if (renderer is HtmlRenderer html && !html.ObjectRenderers.Contains<TocRenderer>())
            html.ObjectRenderers.Add(new TocRenderer());
    }
}

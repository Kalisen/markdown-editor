using Markdig.Syntax.Inlines;
using Markdig.Syntax;
using Markdig;
using Markdig.Parsers.Inlines;
using Markdig.Renderers;
using Markdig.Renderers.Html.Inlines;
using MarkdownEditor.Plugins.Abstractions;
using MarkdownEditor.Plugins.Abstractions.Preview;

namespace MarkdownEditor.Plugin.Strikethrough;

/// <summary>GFM strikethrough: <c>~~text~~</c> and (as on GitHub.com) <c>~text~</c> render as <c>&lt;del&gt;</c>.</summary>
public sealed class StrikethroughPlugin : IMarkdownPlugin, IDocumentFeatureProbe
{
    public const string PluginId = "strikethrough";

    public string Id => PluginId;

    public string Name => "Strikethrough (GFM)";

    public Version Version => new(1, 0, 0);

    public IReadOnlyList<PreviewAsset> PreviewAssets { get; } = [];

    public bool IsUsedBy(MarkdownDocument document) =>
        document.Descendants<EmphasisInline>().Any(e => e.DelimiterChar == StrikethroughExtension.Tilde);

    public void ConfigurePipeline(MarkdownPipelineBuilder builder) =>
        builder.Extensions.AddIfNotAlready<StrikethroughExtension>();
}

internal sealed class StrikethroughExtension : IMarkdownExtension
{
    public const char Tilde = '~';
    private const string DeleteTag = "del";

    public void Setup(MarkdownPipelineBuilder pipeline)
    {
        var parser = pipeline.InlineParsers.FindExact<EmphasisInlineParser>();
        if (parser is not null && !parser.HasEmphasisChar(Tilde))
            parser.EmphasisDescriptors.Add(new EmphasisDescriptor(Tilde, minimumCount: 1, maximumCount: 2, enableWithinWord: false));
    }

    public void Setup(MarkdownPipeline pipeline, IMarkdownRenderer renderer)
    {
        if (renderer is not HtmlRenderer html || html.ObjectRenderers.FindExact<EmphasisInlineRenderer>() is not { } emphasis)
            return;
        var previous = emphasis.GetTag;
        emphasis.GetTag = inline => inline.DelimiterChar == Tilde ? DeleteTag : previous(inline);
    }
}

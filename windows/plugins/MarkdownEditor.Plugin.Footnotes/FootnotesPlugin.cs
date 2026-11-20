using Markdig.Syntax;
using Markdig;
using MarkdownEditor.Plugins.Abstractions;
using MarkdownEditor.Plugins.Abstractions.Preview;

namespace MarkdownEditor.Plugin.Footnotes;

/// <summary>Footnotes as on GitHub: <c>[^1]</c> references, <c>[^1]: text</c> definitions, numbered list with back-links.</summary>
public sealed class FootnotesPlugin : IMarkdownPlugin, IDocumentFeatureProbe
{
    public const string PluginId = "footnotes";
    public const string StylesheetPath = "assets/footnotes.css";

    public string Id => PluginId;

    public string Name => "Footnotes";

    public Version Version => new(1, 0, 0);

    public IReadOnlyList<PreviewAsset> PreviewAssets { get; } = [PreviewAsset.Stylesheet(StylesheetPath)];

    public bool IsUsedBy(MarkdownDocument document) =>
        document.Descendants<Markdig.Extensions.Footnotes.FootnoteGroup>().Any();

    public void ConfigurePipeline(MarkdownPipelineBuilder builder) => builder.UseFootnotes();
}

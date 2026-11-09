using Markdig;
using MarkdownEditor.Plugins.Abstractions;
using MarkdownEditor.Plugins.Abstractions.Preview;

namespace MarkdownEditor.Plugin.Footnotes;

/// <summary>Footnotes as on GitHub: <c>[^1]</c> references, <c>[^1]: text</c> definitions, numbered list with back-links.</summary>
public sealed class FootnotesPlugin : IMarkdownPlugin
{
    public const string PluginId = "footnotes";
    public const string StylesheetPath = "assets/footnotes.css";

    public string Id => PluginId;

    public string Name => "Footnotes";

    public Version Version => new(1, 0, 0);

    public IReadOnlyList<PreviewAsset> PreviewAssets { get; } = [PreviewAsset.Stylesheet(StylesheetPath)];

    public void ConfigurePipeline(MarkdownPipelineBuilder builder) => builder.UseFootnotes();
}

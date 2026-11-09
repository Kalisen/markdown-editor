using Markdig;
using Markdig.Extensions.AutoIdentifiers;
using MarkdownEditor.Plugins.Abstractions;
using MarkdownEditor.Plugins.Abstractions.Preview;

namespace MarkdownEditor.Plugin.HeadingAnchors;

/// <summary>
/// GitHub-compatible heading ids (lowercase, spaces to hyphens, punctuation removed, duplicates suffixed
/// <c>-1</c>, <c>-2</c>…) so <c>#section</c> links work, plus a link icon shown on hover.
/// </summary>
public sealed class HeadingAnchorsPlugin : IMarkdownPlugin
{
    public const string PluginId = "heading-anchors";
    public const string ScriptPath = "assets/heading-anchors.js";
    public const string StylesheetPath = "assets/heading-anchors.css";

    public string Id => PluginId;

    public string Name => "Heading anchors";

    public Version Version => new(1, 0, 0);

    public IReadOnlyList<PreviewAsset> PreviewAssets { get; } =
        [PreviewAsset.Stylesheet(StylesheetPath), PreviewAsset.Script(ScriptPath)];

    public void ConfigurePipeline(MarkdownPipelineBuilder builder) => builder.UseAutoIdentifiers(AutoIdentifierOptions.GitHub);
}

using Markdig.Syntax;
using Markdig;
using MarkdownEditor.Plugins.Abstractions;
using MarkdownEditor.Plugins.Abstractions.Preview;

namespace MarkdownEditor.Plugin.Mermaid;

/// <summary>
/// Renders <c>```mermaid</c> fenced code blocks as diagrams using a bundled Mermaid build.
/// </summary>
public sealed class MermaidPlugin : IMarkdownPlugin, IDocumentFeatureProbe
{
    public const string PluginId = "mermaid";
    public const string MermaidVersion = "12.3.0";
    public const string MermaidScriptPath = $"assets/vendor/mermaid-{MermaidVersion}/mermaid.min.js";
    public const string BootstrapScriptPath = "assets/mermaid-preview.js";
    public const string StylesheetPath = "assets/mermaid-preview.css";

    public string Id => PluginId;

    public string Name => "Mermaid diagrams";

    public Version Version => new(1, 0, 0);

    /// <remarks>Mermaid must load before the bootstrap script that uses it.</remarks>
    public IReadOnlyList<PreviewAsset> PreviewAssets { get; } =
    [
        PreviewAsset.Stylesheet(StylesheetPath),
        PreviewAsset.Script(MermaidScriptPath),
        PreviewAsset.Script(BootstrapScriptPath),
    ];

    public bool IsUsedBy(MarkdownDocument document) =>
        document.Descendants<FencedCodeBlock>().Any(MermaidCodeBlockRenderer.IsMermaid);

    public void ConfigurePipeline(MarkdownPipelineBuilder builder) =>
        builder.Extensions.AddIfNotAlready<MermaidExtension>();
}

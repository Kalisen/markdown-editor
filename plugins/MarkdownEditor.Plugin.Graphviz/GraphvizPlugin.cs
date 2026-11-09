using Markdig.Syntax;
using Markdig;
using MarkdownEditor.Plugins.Abstractions;
using MarkdownEditor.Plugins.Abstractions.Preview;

namespace MarkdownEditor.Plugin.Graphviz;

/// <summary>
/// Renders <c>```dot</c> / <c>```graphviz</c> fenced blocks as diagrams with a bundled Graphviz
/// (Viz.js, WebAssembly). Markdown rendering is unchanged; diagrams are drawn in the preview.
/// </summary>
public sealed class GraphvizPlugin : IMarkdownPlugin, IDocumentFeatureProbe
{
    public const string PluginId = "graphviz";
    public const string VizVersion = "3.31.0";
    public const string VizScriptPath = $"assets/vendor/viz-{VizVersion}/viz-global.js";
    public const string BootstrapScriptPath = "assets/graphviz.js";
    public const string StylesheetPath = "assets/graphviz.css";
    public static readonly IReadOnlyList<string> Languages = ["dot", "graphviz"];

    public string Id => PluginId;

    public string Name => "Graphviz diagrams";

    public Version Version => new(1, 0, 0);

    public IReadOnlyList<PreviewAsset> PreviewAssets { get; } =
    [
        PreviewAsset.Stylesheet(StylesheetPath),
        PreviewAsset.Script(VizScriptPath),
        PreviewAsset.Script(BootstrapScriptPath),
    ];

    public bool IsUsedBy(MarkdownDocument document) =>
        document.Descendants<FencedCodeBlock>().Any(b => b.Info is { } info && Languages.Contains(info));

    public void ConfigurePipeline(MarkdownPipelineBuilder builder)
    {
    }
}

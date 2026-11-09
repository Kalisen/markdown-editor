using Markdig.Syntax;
using Markdig;
using MarkdownEditor.Plugins.Abstractions;
using MarkdownEditor.Plugins.Abstractions.Preview;

namespace MarkdownEditor.Plugin.SyntaxHighlighting;

/// <summary>
/// Highlights fenced code blocks that declare a language (<c>```csharp</c>), using a bundled highlight.js
/// with GitHub's light/dark colours. Rendering is unchanged: CommonMark already emits
/// <c>class="language-x"</c>; highlighting happens in the preview.
/// </summary>
public sealed class SyntaxHighlightingPlugin : IMarkdownPlugin, IDocumentFeatureProbe
{
    public const string PluginId = "syntax-highlighting";
    public const string HighlightJsVersion = "11.12.0";
    public const string VendorFolder = $"assets/vendor/highlightjs-{HighlightJsVersion}";
    public const string HighlightJsPath = $"{VendorFolder}/highlight.min.js";
    public const string LightThemePath = $"{VendorFolder}/github.min.css";
    public const string DarkThemePath = $"{VendorFolder}/github-dark.min.css";
    public const string BootstrapScriptPath = "assets/syntax-highlighting.js";
    public const string StylesheetPath = "assets/syntax-highlighting.css";

    /// <summary>Fence languages drawn by other plugins rather than highlighted (kept in sync with the script).</summary>
    public static readonly IReadOnlySet<string> RenderedByOtherPlugins = new HashSet<string>(StringComparer.Ordinal) { "math", "mermaid", "dot", "graphviz" };

    public string Id => PluginId;

    public string Name => "Syntax highlighting";

    public Version Version => new(1, 0, 0);

    /// <remarks>
    /// The theme stylesheet (light or dark) is added by the bootstrap script, which knows the preview theme.
    /// </remarks>
    public IReadOnlyList<PreviewAsset> PreviewAssets { get; } =
    [
        PreviewAsset.Stylesheet(StylesheetPath),
        PreviewAsset.Script(HighlightJsPath),
        PreviewAsset.Script(BootstrapScriptPath),
    ];

    public bool IsUsedBy(MarkdownDocument document) =>
        document.Descendants<FencedCodeBlock>().Any(b => b.Info is { Length: > 0 } info && !RenderedByOtherPlugins.Contains(info));

    public void ConfigurePipeline(MarkdownPipelineBuilder builder)
    {
    }
}

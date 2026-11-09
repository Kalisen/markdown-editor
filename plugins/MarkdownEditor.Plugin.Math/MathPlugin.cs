using Markdig;
using Markdig.Extensions.Mathematics;
using Markdig.Helpers;
using Markdig.Renderers;
using Markdig.Syntax;
using MarkdownEditor.Plugins.Abstractions;
using MarkdownEditor.Plugins.Abstractions.Preview;

namespace MarkdownEditor.Plugin.Math;

/// <summary>
/// Math as on GitHub: <c>$inline$</c>, <c>$`inline`$</c>, <c>$$block$$</c> and <c>```math</c> fences,
/// typeset in the preview by a bundled KaTeX.
/// </summary>
public sealed class MathPlugin : IMarkdownPlugin
{
    public const string PluginId = "math";
    public const string KatexVersion = "0.19.1";
    public const string VendorFolder = $"assets/vendor/katex-{KatexVersion}";
    public const string KatexScriptPath = $"{VendorFolder}/katex.min.js";
    public const string KatexStylesheetPath = $"{VendorFolder}/katex.min.css";
    public const string BootstrapScriptPath = "assets/math.js";
    public const string StylesheetPath = "assets/math.css";

    public string Id => PluginId;

    public string Name => "Math";

    public Version Version => new(1, 0, 0);

    public IReadOnlyList<PreviewAsset> PreviewAssets { get; } =
    [
        PreviewAsset.Stylesheet(KatexStylesheetPath),
        PreviewAsset.Stylesheet(StylesheetPath),
        PreviewAsset.Script(KatexScriptPath),
        PreviewAsset.Script(BootstrapScriptPath),
    ];

    public void ConfigurePipeline(MarkdownPipelineBuilder builder)
    {
        builder.UseMathematics();
        builder.Extensions.AddIfNotAlready<BacktickMathExtension>();
    }
}

/// <summary>GitHub's <c>$`…`$</c> inline form: the backticks only delimit the expression.</summary>
internal sealed class BacktickMathExtension : IMarkdownExtension
{
    private const char Backtick = '`';

    public void Setup(MarkdownPipelineBuilder pipeline)
    {
        pipeline.DocumentProcessed -= Process;
        pipeline.DocumentProcessed += Process;
    }

    public void Setup(MarkdownPipeline pipeline, IMarkdownRenderer renderer)
    {
    }

    internal static void Process(MarkdownDocument document)
    {
        foreach (var math in document.Descendants<MathInline>())
        {
            var content = math.Content.ToString();
            if (content.Length >= 2 && content[0] == Backtick && content[^1] == Backtick)
                math.Content = new StringSlice(content[1..^1]);
        }
    }
}

using Markdig;
using Markdig.Extensions.Alerts;
using Markdig.Helpers;
using Markdig.Parsers;
using MarkdownEditor.Plugins.Abstractions;
using MarkdownEditor.Plugins.Abstractions.Preview;

namespace MarkdownEditor.Plugin.Alerts;

/// <summary>GitHub alert kinds (case-insensitive in the source).</summary>
public enum AlertKind
{
    Note,
    Tip,
    Important,
    Warning,
    Caution,
}

/// <summary>GitHub alerts: blockquotes starting with <c>[!NOTE]</c>, <c>[!TIP]</c>, <c>[!IMPORTANT]</c>, <c>[!WARNING]</c>, <c>[!CAUTION]</c>.</summary>
public sealed class AlertsPlugin : IMarkdownPlugin
{
    public const string PluginId = "alerts";
    public const string StylesheetPath = "assets/alerts.css";

    public string Id => PluginId;

    public string Name => "Alerts";

    public Version Version => new(1, 0, 0);

    public IReadOnlyList<PreviewAsset> PreviewAssets { get; } = [PreviewAsset.Stylesheet(StylesheetPath)];

    public void ConfigurePipeline(MarkdownPipelineBuilder builder)
    {
        builder.UseAlertBlocks();
        // Extensions are set up in registration order when the pipeline is built, so this runs after
        // the alert extension has added its parser.
        builder.Extensions.AddIfNotAlready<GitHubAlertKindsExtension>();
    }
}

internal sealed class GitHubAlertKindsExtension : IMarkdownExtension
{
    public void Setup(MarkdownPipelineBuilder pipeline)
    {
        if (pipeline.InlineParsers.FindExact<AlertInlineParser>() is not null)
            pipeline.InlineParsers.Replace<AlertInlineParser>(new GitHubAlertInlineParser());
    }

    public void Setup(MarkdownPipeline pipeline, Markdig.Renderers.IMarkdownRenderer renderer)
    {
    }
}

/// <summary>Only the five GitHub alert kinds become alerts; any other <c>[!X]</c> stays a normal blockquote.</summary>
internal sealed class GitHubAlertInlineParser : AlertInlineParser
{
    private const string Prefix = "[!";
    private const char Close = ']';

    public override bool Match(InlineProcessor processor, ref StringSlice slice)
    {
        var text = slice.Text.AsSpan(slice.Start, slice.Length);
        if (!text.StartsWith(Prefix, StringComparison.Ordinal)) return false;
        var end = text.IndexOf(Close);
        if (end < 0 || !Enum.TryParse<AlertKind>(text[Prefix.Length..end], ignoreCase: true, out _)) return false;
        return base.Match(processor, ref slice);
    }
}

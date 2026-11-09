using System.Text.RegularExpressions;
using Markdig;
using Markdig.Helpers;
using Markdig.Renderers;
using Markdig.Syntax;
using Markdig.Syntax.Inlines;
using MarkdownEditor.Plugins.Abstractions;
using MarkdownEditor.Plugins.Abstractions.Preview;

namespace MarkdownEditor.Plugin.TagFilter;

/// <summary>
/// GFM disallowed raw HTML (spec 0.29, section 6.11): in raw HTML, the leading <c>&lt;</c> of
/// title, textarea, style, xmp, iframe, noembed, noframes, script and plaintext tags is escaped.
/// </summary>
public sealed class TagFilterPlugin : IMarkdownPlugin, IDocumentFeatureProbe
{
    public const string PluginId = "tag-filter";

    public string Id => PluginId;

    public string Name => "Disallowed raw HTML (GFM)";

    public Version Version => new(1, 0, 0);

    public IReadOnlyList<PreviewAsset> PreviewAssets { get; } = [];

    public bool IsUsedBy(MarkdownDocument document) =>
        document.GetData(TagFilterExtension.FilteredKey) is true;

    public void ConfigurePipeline(MarkdownPipelineBuilder builder) =>
        builder.Extensions.AddIfNotAlready<TagFilterExtension>();
}

internal sealed partial class TagFilterExtension : IMarkdownExtension
{
    private const string EscapedLessThan = "&lt;";

    /// <summary>Document data flag set when a disallowed tag was escaped (used to report the plugin as in use).</summary>
    public static readonly object FilteredKey = new();

    [GeneratedRegex(@"<(?=/?(title|textarea|style|xmp|iframe|noembed|noframes|script|plaintext)(?:[\s/>]|$))",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex DisallowedTag();

    public static string Filter(string html) => DisallowedTag().Replace(html, EscapedLessThan);

    public void Setup(MarkdownPipelineBuilder pipeline)
    {
        pipeline.DocumentProcessed -= Process;
        pipeline.DocumentProcessed += Process;
    }

    public void Setup(MarkdownPipeline pipeline, IMarkdownRenderer renderer)
    {
    }

    private static void Process(MarkdownDocument document)
    {
        foreach (var block in document.Descendants<HtmlBlock>())
        {
            var original = block.Lines.ToString();
            var filtered = Filter(original);
            if (filtered == original) continue;
            block.Lines = new StringLineGroup(filtered);
            document.SetData(FilteredKey, true);
        }
        foreach (var inline in document.Descendants<HtmlInline>())
        {
            var filtered = Filter(inline.Tag);
            if (filtered == inline.Tag) continue;
            inline.Tag = filtered;
            document.SetData(FilteredKey, true);
        }
    }
}

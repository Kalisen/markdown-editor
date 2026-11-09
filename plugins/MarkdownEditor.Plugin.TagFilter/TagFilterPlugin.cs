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
public sealed class TagFilterPlugin : IMarkdownPlugin
{
    public const string PluginId = "tag-filter";

    public string Id => PluginId;

    public string Name => "Disallowed raw HTML (GFM)";

    public Version Version => new(1, 0, 0);

    public IReadOnlyList<PreviewAsset> PreviewAssets { get; } = [];

    public void ConfigurePipeline(MarkdownPipelineBuilder builder) =>
        builder.Extensions.AddIfNotAlready<TagFilterExtension>();
}

internal sealed partial class TagFilterExtension : IMarkdownExtension
{
    private const string EscapedLessThan = "&lt;";

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
            var filtered = Filter(block.Lines.ToString());
            if (filtered != block.Lines.ToString()) block.Lines = new StringLineGroup(filtered);
        }
        foreach (var inline in document.Descendants<HtmlInline>())
            inline.Tag = Filter(inline.Tag);
    }
}

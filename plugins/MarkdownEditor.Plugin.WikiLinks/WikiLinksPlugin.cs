using Markdig;
using Markdig.Helpers;
using Markdig.Parsers;
using Markdig.Parsers.Inlines;
using Markdig.Renderers;
using Markdig.Renderers.Html;
using Markdig.Syntax.Inlines;
using MarkdownEditor.Plugins.Abstractions;
using MarkdownEditor.Plugins.Abstractions.Preview;

namespace MarkdownEditor.Plugin.WikiLinks;

/// <summary>
/// Obsidian-style wikilinks: <c>[[Note]]</c>, <c>[[folder/Note|alias]]</c>, <c>[[Note#Heading]]</c> link to
/// <c>Note.md</c>; the editor opens them like any other link to a Markdown file.
/// </summary>
public sealed class WikiLinksPlugin : IMarkdownPlugin
{
    public const string PluginId = "wikilinks";
    public const string StylesheetPath = "assets/wikilinks.css";

    public string Id => PluginId;

    public string Name => "Wikilinks";

    public Version Version => new(1, 0, 0);

    public IReadOnlyList<PreviewAsset> PreviewAssets { get; } = [PreviewAsset.Stylesheet(StylesheetPath)];

    public void ConfigurePipeline(MarkdownPipelineBuilder builder) =>
        builder.Extensions.AddIfNotAlready<WikiLinkExtension>();
}

internal sealed class WikiLinkExtension : IMarkdownExtension
{
    public void Setup(MarkdownPipelineBuilder pipeline)
    {
        // Before the standard link parser, which would otherwise consume the outer '['.
        if (!pipeline.InlineParsers.Contains<WikiLinkParser>())
            pipeline.InlineParsers.InsertBefore<LinkInlineParser>(new WikiLinkParser());
    }

    public void Setup(MarkdownPipeline pipeline, IMarkdownRenderer renderer)
    {
    }
}

/// <summary>Parses <c>[[target#heading|alias]]</c> into a link carrying the <c>wikilink</c> class.</summary>
internal sealed class WikiLinkParser : InlineParser
{
    public const string CssClass = "wikilink";
    public const string MarkdownExtension = ".md";
    private const string Open = "[[";
    private const string Close = "]]";

    public WikiLinkParser() => OpeningCharacters = ['['];

    public override bool Match(InlineProcessor processor, ref StringSlice slice)
    {
        var text = slice.Text.AsSpan(slice.Start, slice.Length);
        if (!text.StartsWith(Open, StringComparison.Ordinal)) return false;
        var end = text.IndexOf(Close, StringComparison.Ordinal);
        if (end <= Open.Length) return false;
        var inner = text[Open.Length..end].ToString();
        if (inner.Contains('\n') || inner.Contains('[')) return false;

        if (WikiLinkTarget.Parse(inner) is not { } target) return false;

        var link = new LinkInline(target.Url, string.Empty)
        {
            Span = new(processor.GetSourcePosition(slice.Start, out var line, out var column), 0),
            Line = line,
            Column = column,
            IsClosed = true,
        };
        link.GetAttributes().AddClass(CssClass);
        link.AppendChild(new LiteralInline(target.Label));
        processor.Inline = link;
        slice.Start += end + Close.Length;
        return true;
    }
}

/// <summary>The parts of a wikilink and the relative URL it points to.</summary>
public sealed record WikiLinkTarget(string Note, string? Heading, string Label, string Url)
{
    private const char HeadingSeparator = '#';
    private const char AliasSeparator = '|';

    public static WikiLinkTarget? Parse(string inner)
    {
        var aliasIndex = inner.IndexOf(AliasSeparator);
        var alias = aliasIndex >= 0 ? inner[(aliasIndex + 1)..].Trim() : null;
        var reference = (aliasIndex >= 0 ? inner[..aliasIndex] : inner).Trim();

        var headingIndex = reference.IndexOf(HeadingSeparator);
        var note = (headingIndex >= 0 ? reference[..headingIndex] : reference).Trim();
        var heading = headingIndex >= 0 ? reference[(headingIndex + 1)..].Trim() : null;
        if (note.Length == 0) return null;

        var file = Path.HasExtension(note) ? note : note + WikiLinkParser.MarkdownExtension;
        var label = !string.IsNullOrEmpty(alias) ? alias : string.IsNullOrEmpty(heading) ? note : $"{note} > {heading}";
        return new WikiLinkTarget(note, string.IsNullOrEmpty(heading) ? null : heading, label, file.Replace('\\', '/'));
    }
}

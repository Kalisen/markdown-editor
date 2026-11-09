using System.Text;
using Markdig;
using Markdig.Renderers;
using Markdig.Syntax;
using Markdig.Syntax.Inlines;
using MarkdownEditor.Plugins.Abstractions;
using MarkdownEditor.Plugins.Abstractions.Preview;

namespace MarkdownEditor.Plugin.Autolinks;

/// <summary>GFM extended autolinks: bare <c>www.</c>, <c>http(s)://</c> URLs and email addresses become links.</summary>
public sealed class AutolinksPlugin : IMarkdownPlugin
{
    public const string PluginId = "autolinks";

    public string Id => PluginId;

    public string Name => "Autolinks (GFM)";

    public Version Version => new(1, 0, 0);

    public IReadOnlyList<PreviewAsset> PreviewAssets { get; } = [];

    public void ConfigurePipeline(MarkdownPipelineBuilder builder) =>
        builder.Extensions.AddIfNotAlready<GfmAutolinkExtension>();
}

/// <summary>
/// Runs after inline parsing: scans runs of plain text (never inside links, code or raw HTML) and
/// replaces matches with autolinks.
/// </summary>
internal sealed class GfmAutolinkExtension : IMarkdownExtension
{
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
        foreach (var leaf in document.Descendants<LeafBlock>())
            if (leaf.Inline is { } inline) ProcessContainer(inline);
    }

    private static void ProcessContainer(ContainerInline container)
    {
        if (container is LinkInline) return;

        var child = container.FirstChild;
        while (child is not null)
        {
            if (child is LiteralInline first)
            {
                // Merge a run of adjacent literals (Markdig splits text at unmatched delimiters such as '_').
                var run = new List<LiteralInline> { first };
                while (run[^1].NextSibling is LiteralInline next) run.Add(next);
                var after = run[^1].NextSibling;
                Rewrite(run, startsAtBoundary: first.PreviousSibling is not LiteralInline);
                child = after;
                continue;
            }
            if (child is ContainerInline nested) ProcessContainer(nested);
            child = child.NextSibling;
        }
    }

    private static void Rewrite(List<LiteralInline> run, bool startsAtBoundary)
    {
        var text = new StringBuilder();
        foreach (var literal in run) text.Append(literal.Content.ToString());
        var source = text.ToString();
        var matches = GfmAutolinkScanner.Scan(source, startsAtBoundary);
        if (matches.Count == 0) return;

        var anchor = run[0];
        var position = 0;
        foreach (var match in matches)
        {
            if (match.Start > position) anchor.InsertBefore(new LiteralInline(source[position..match.Start]));
            var link = new LinkInline(match.Url, string.Empty) { IsAutoLink = true };
            link.AppendChild(new LiteralInline(source.Substring(match.Start, match.Length)));
            anchor.InsertBefore(link);
            position = match.Start + match.Length;
        }
        if (position < source.Length) anchor.InsertBefore(new LiteralInline(source[position..]));
        foreach (var literal in run) literal.Remove();
    }
}

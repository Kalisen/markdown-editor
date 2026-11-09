using System.Text;
using Markdig;
using Markdig.Renderers;
using Markdig.Syntax;
using Markdig.Syntax.Inlines;
using MarkdownEditor.Plugins.Abstractions;
using MarkdownEditor.Plugins.Abstractions.Preview;

namespace MarkdownEditor.Plugin.Autolinks;

/// <summary>GFM extended autolinks: bare <c>www.</c>, <c>http(s)://</c> URLs and email addresses become links.</summary>
public sealed class AutolinksPlugin : IMarkdownPlugin, IDocumentFeatureProbe
{
    public const string PluginId = "autolinks";

    public string Id => PluginId;

    public string Name => "Autolinks (GFM)";

    public Version Version => new(1, 0, 0);

    public IReadOnlyList<PreviewAsset> PreviewAssets { get; } = [];

    public bool IsUsedBy(MarkdownDocument document) =>
        document.Descendants<LinkInline>().Any(l => l.IsAutoLink);

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

        var original = new List<Inline>();
        for (var child = container.FirstChild; child is not null; child = child.NextSibling) original.Add(child);

        var rebuilt = new List<Inline>();
        var changed = false;
        for (var i = 0; i < original.Count; i++)
        {
            if (original[i] is LiteralInline)
            {
                // Merge a run of adjacent literals (Markdig splits text at unmatched delimiters such as '_').
                var run = new List<LiteralInline>();
                var startsAtBoundary = i == 0 || original[i - 1] is not LiteralInline;
                while (i < original.Count && original[i] is LiteralInline literal) { run.Add(literal); i++; }
                i--;
                if (Rewrite(run, startsAtBoundary) is { } replacement)
                {
                    rebuilt.AddRange(replacement);
                    changed = true;
                }
                else
                {
                    rebuilt.AddRange(run);
                }
                continue;
            }
            if (original[i] is ContainerInline nested) ProcessContainer(nested);
            rebuilt.Add(original[i]);
        }

        if (!changed) return;
        // Rebuild the child list with AppendChild only: splicing with InsertBefore can leave Markdig's
        // sibling/last-child links inconsistent, hiding nodes from later tree walks.
        foreach (var child in original) child.Remove();
        foreach (var child in rebuilt) container.AppendChild(child);
    }

    /// <returns>The nodes replacing the run, or null when it contains no autolink.</returns>
    private static List<Inline>? Rewrite(List<LiteralInline> run, bool startsAtBoundary)
    {
        var text = new StringBuilder();
        foreach (var literal in run) text.Append(literal.Content.ToString());
        var source = text.ToString();
        var matches = GfmAutolinkScanner.Scan(source, startsAtBoundary);
        if (matches.Count == 0) return null;

        var replacement = new List<Inline>();
        var position = 0;
        foreach (var match in matches)
        {
            if (match.Start > position) replacement.Add(new LiteralInline(source[position..match.Start]));
            var link = new LinkInline(match.Url, string.Empty) { IsAutoLink = true };
            link.AppendChild(new LiteralInline(source.Substring(match.Start, match.Length)));
            replacement.Add(link);
            position = match.Start + match.Length;
        }
        if (position < source.Length) replacement.Add(new LiteralInline(source[position..]));
        return replacement;
    }
}

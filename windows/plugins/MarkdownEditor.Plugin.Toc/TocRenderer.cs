using System.Text;
using Markdig.Renderers;
using Markdig.Renderers.Html;
using Markdig.Syntax;
using Markdig.Syntax.Inlines;

namespace MarkdownEditor.Plugin.Toc;

/// <summary>Renders the headings of the whole document as nested lists (relative levels, like GitLab).</summary>
internal sealed class TocRenderer : HtmlObjectRenderer<TocBlock>
{
    public const string NavClass = "table-of-contents";

    protected override void Write(HtmlRenderer renderer, TocBlock block)
    {
        var root = (Block)block;
        while (root.Parent is not null) root = root.Parent;
        var entries = root is MarkdownDocument document
            ? document.Descendants<HeadingBlock>().Select(h => (h.Level, Id: h.GetAttributes().Id, Text: PlainText(h.Inline)))
                .Where(e => !string.IsNullOrEmpty(e.Id)).ToList()
            : [];

        renderer.EnsureLine();
        renderer.Write("<nav class=\"").Write(NavClass).WriteLine("\">");
        renderer.Write(BuildList(entries));
        renderer.WriteLine("</nav>");
    }

    internal static string BuildList(IReadOnlyList<(int Level, string? Id, string Text)> entries)
    {
        var html = new StringBuilder();
        var open = new Stack<int>();
        foreach (var (level, id, text) in entries)
        {
            if (open.Count == 0 || level > open.Peek())
            {
                html.Append("<ul>\n");
                open.Push(level);
            }
            else
            {
                html.Append("</li>\n");
                while (open.Count > 1 && level < open.Peek())
                {
                    open.Pop();
                    html.Append("</ul>\n</li>\n");
                }
            }
            html.Append("<li><a href=\"#").Append(Escape(id!)).Append("\">").Append(Escape(text)).Append("</a>");
        }
        if (open.Count > 0) html.Append("</li>\n");
        while (open.Count > 0)
        {
            open.Pop();
            html.Append("</ul>\n");
            if (open.Count > 0) html.Append("</li>\n");
        }
        return html.ToString();
    }

    private static string Escape(string text) => System.Net.WebUtility.HtmlEncode(text);

    private static string PlainText(ContainerInline? inline)
    {
        var text = new StringBuilder();
        if (inline is null) return string.Empty;
        foreach (var node in inline.Descendants())
        {
            switch (node)
            {
                case LiteralInline literal: text.Append(literal.Content.ToString()); break;
                case CodeInline code: text.Append(code.Content); break;
                case LineBreakInline: text.Append(' '); break;
            }
        }
        return text.ToString().Trim();
    }
}

using Markdig.Renderers;
using Markdig.Renderers.Html;
using Markdig.Syntax;

namespace MarkdownEditor.Plugin.Mermaid;

/// <summary>
/// Emits <c>&lt;div class="mermaid-diagram"&gt;&lt;pre class="mermaid-source"&gt;…&lt;/pre&gt;&lt;/div&gt;</c>
/// for Mermaid fenced blocks (the preview script replaces the source with an SVG);
/// every other code block is delegated to the original renderer.
/// </summary>
internal sealed class MermaidCodeBlockRenderer(CodeBlockRenderer fallback) : CodeBlockRenderer
{
    public const string InfoString = "mermaid";
    public const string DiagramClass = "mermaid-diagram";
    public const string SourceClass = "mermaid-source";

    internal static bool IsMermaid(CodeBlock block) =>
        block is FencedCodeBlock { Info: { } info } && string.Equals(info, InfoString, StringComparison.Ordinal);

    protected override void Write(HtmlRenderer renderer, CodeBlock block)
    {
        if (!IsMermaid(block))
        {
            fallback.Write(renderer, block);
            return;
        }

        renderer.EnsureLine();
        renderer.Write("<div class=\"").Write(DiagramClass).Write("\"><pre class=\"").Write(SourceClass).Write("\">");
        renderer.WriteLeafRawLines(block, writeEndOfLines: true, escape: true);
        renderer.WriteLine("</pre></div>");
    }
}

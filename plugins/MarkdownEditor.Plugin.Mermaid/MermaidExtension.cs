using Markdig;
using Markdig.Renderers;
using Markdig.Renderers.Html;

namespace MarkdownEditor.Plugin.Mermaid;

/// <summary>Wraps the HTML code block renderer so Mermaid blocks get diagram markup.</summary>
internal sealed class MermaidExtension : IMarkdownExtension
{
    public void Setup(MarkdownPipelineBuilder pipeline)
    {
    }

    public void Setup(MarkdownPipeline pipeline, IMarkdownRenderer renderer)
    {
        if (renderer is not HtmlRenderer html) return;
        var original = html.ObjectRenderers.FindExact<CodeBlockRenderer>();
        if (original is null) return;
        html.ObjectRenderers.Replace<CodeBlockRenderer>(new MermaidCodeBlockRenderer(original));
    }
}

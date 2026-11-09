using Markdig;
using Markdig.Renderers;
using Markdig.Renderers.Html;
using Markdig.Syntax;
using Markdig.Syntax.Inlines;

namespace MarkdownEditor.Plugin.Images;

internal sealed class ImageExtension : IMarkdownExtension
{
    public void Setup(MarkdownPipelineBuilder pipeline)
    {
        pipeline.DocumentProcessed -= Rewrite;
        pipeline.DocumentProcessed += Rewrite;
    }

    public void Setup(MarkdownPipeline pipeline, IMarkdownRenderer renderer)
    {
    }

    internal static void Rewrite(MarkdownDocument document)
    {
        foreach (var image in document.Descendants<LinkInline>().Where(l => l.IsImage))
        {
            if (image.Url is { } url) image.Url = ImageUrlResolver.Resolve(url);

            if (ImageSizeHint.TryParse(image.Title, out var hint))
            {
                image.Title = null;
                var attributes = image.GetAttributes();
                if (hint.Width is { } w) attributes.AddProperty("width", w.ToString());
                if (hint.Height is { } h) attributes.AddProperty("height", h.ToString());
            }
            image.GetAttributes().AddProperty("loading", "lazy");
        }
    }
}

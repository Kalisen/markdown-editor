using System.Xml;
using ICSharpCode.AvalonEdit.Highlighting;
using ICSharpCode.AvalonEdit.Highlighting.Xshd;

namespace MarkdownEditor.App.Editing;

internal static class MarkdownHighlighting
{
    private const string ResourceName = "MarkdownEditor.App.Editing.Markdown.xshd";

    public static IHighlightingDefinition Load()
    {
        using var stream = typeof(MarkdownHighlighting).Assembly.GetManifestResourceStream(ResourceName)
                           ?? throw new InvalidOperationException($"Missing resource {ResourceName}");
        using var reader = XmlReader.Create(stream);
        return HighlightingLoader.Load(reader, HighlightingManager.Instance);
    }
}

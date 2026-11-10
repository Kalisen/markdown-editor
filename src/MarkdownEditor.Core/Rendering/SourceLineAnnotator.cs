using Markdig.Renderers.Html;
using Markdig.Syntax;

namespace MarkdownEditor.Core.Rendering;

/// <summary>
/// Tags rendered blocks with the 0-based source line range they come from, so the preview can map
/// between editor lines and rendered positions (scroll synchronization). See Assets/preview.js.
/// </summary>
public static class SourceLineAnnotator
{
    /// <summary>First source line of the block (0-based).</summary>
    public const string StartAttribute = "data-line";

    /// <summary>Last source line of the block (0-based, inclusive).</summary>
    public const string EndAttribute = "data-line-end";

    public static void Annotate(MarkdownDocument document, string markdown)
    {
        var lineStarts = LineStarts(markdown);
        foreach (var block in document.Descendants<Block>())
        {
            if (block.Line < 0 || block.Span.IsEmpty) continue;
            var end = Math.Max(block.Line, LineOf(lineStarts, block.Span.End));
            var attributes = block.GetAttributes();
            attributes.AddPropertyIfNotExist(StartAttribute, block.Line.ToString(System.Globalization.CultureInfo.InvariantCulture));
            attributes.AddPropertyIfNotExist(EndAttribute, end.ToString(System.Globalization.CultureInfo.InvariantCulture));
        }
    }

    /// <summary>Offsets at which each line starts; line breaks are \n, \r\n or \r, as Markdig counts them.</summary>
    private static List<int> LineStarts(string text)
    {
        var starts = new List<int> { 0 };
        for (var i = 0; i < text.Length; i++)
        {
            if (text[i] == '\r' && i + 1 < text.Length && text[i + 1] == '\n') i++;
            if (text[i] is '\n' or '\r') starts.Add(i + 1);
        }
        return starts;
    }

    private static int LineOf(List<int> lineStarts, int offset)
    {
        var index = lineStarts.BinarySearch(offset);
        return index >= 0 ? index : ~index - 1;
    }
}

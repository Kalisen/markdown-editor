using ICSharpCode.AvalonEdit.Rendering;

namespace MarkdownEditor.App.Scrolling;

/// <summary>Converts between the editor's vertical scroll offset and fractional 0-based source lines.</summary>
internal static class EditorLineGeometry
{
    /// <summary>The fractional source line at the top of the view: a wrapped line counts as one line spanning its visual rows.</summary>
    public static double TopLine(TextView view)
    {
        if (view.Document is not { } document || document.LineCount == 0) return 0;
        var line = view.GetDocumentLineByVisualTop(view.VerticalOffset);
        var (top, bottom) = Bounds(view, line.LineNumber);
        return line.LineNumber - 1 + Fraction(view.VerticalOffset, top, bottom);
    }

    /// <summary>The vertical offset showing the given fractional source line at the top.</summary>
    public static double OffsetOf(TextView view, double line)
    {
        if (view.Document is not { } document || document.LineCount == 0) return 0;
        var index = Math.Clamp((int)Math.Floor(line), 0, document.LineCount - 1);
        var (top, bottom) = Bounds(view, index + 1);
        return top + Math.Clamp(line - index, 0, 1) * (bottom - top);
    }

    /// <summary>How far <paramref name="offset"/> is into the span [top, bottom), from 0 to 1.</summary>
    internal static double Fraction(double offset, double top, double bottom) =>
        bottom > top ? Math.Clamp((offset - top) / (bottom - top), 0, 1) : 0;

    private static (double Top, double Bottom) Bounds(TextView view, int lineNumber)
    {
        var top = view.GetVisualTopByDocumentLine(lineNumber);
        var bottom = lineNumber < view.Document.LineCount
            ? view.GetVisualTopByDocumentLine(lineNumber + 1)
            : view.DocumentHeight;
        return (top, bottom);
    }
}

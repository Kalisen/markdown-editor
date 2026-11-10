namespace MarkdownEditor.Core.Rendering;

/// <summary>
/// Where a panel is scrolled, in terms the other panel can follow.
/// </summary>
/// <param name="Line">Fractional 0-based source line at the top of the panel.</param>
/// <param name="Tail">
/// Progress (0 to 1) through the panel's last viewport-height of scrolling: 0 before it, 1 at the very end.
/// The follower blends from the line position toward its own end by this amount, so both panels reach their
/// end together even when one is much taller than the other (see <see cref="ScrollTail"/>).
/// </param>
public readonly record struct ScrollPosition(double Line, double Tail = 0);

/// <summary>The end-of-document blending shared by both panels (mirrored in Assets/preview.js).</summary>
public static class ScrollTail
{
    /// <summary>Progress through the last <paramref name="viewport"/> of the scroll range [0, <paramref name="maxOffset"/>].</summary>
    public static double Progress(double offset, double maxOffset, double viewport)
    {
        if (maxOffset <= 0) return 0;
        var start = Math.Max(0, maxOffset - viewport);
        return Math.Clamp((offset - start) / (maxOffset - start), 0, 1);
    }

    /// <summary>The follower's offset: the line-matched offset, moved toward the follower's end by <paramref name="tail"/>.</summary>
    public static double Blend(double lineOffset, double maxOffset, double tail) =>
        lineOffset + (maxOffset - lineOffset) * Math.Clamp(tail, 0, 1);
}

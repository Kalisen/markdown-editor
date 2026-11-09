namespace MarkdownEditor.Core.Rendering;

/// <summary>
/// Renders off the calling (UI) thread and keeps only the latest request: a render that finishes
/// after a newer one was requested yields null so stale HTML is never displayed.
/// </summary>
public sealed class BackgroundRenderer(Func<string, string> render)
{
    private int _latest;

    /// <returns>The HTML, or null when superseded by a newer request.</returns>
    public async Task<string?> RenderAsync(string markdown)
    {
        var request = Interlocked.Increment(ref _latest);
        var html = await Task.Run(() => render(markdown));
        return request == Volatile.Read(ref _latest) ? html : null;
    }
}

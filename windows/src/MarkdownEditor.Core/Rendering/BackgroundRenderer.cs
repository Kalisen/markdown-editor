namespace MarkdownEditor.Core.Rendering;

/// <summary>
/// Renders off the calling (UI) thread and keeps only the latest request: a render that finishes
/// after a newer one was requested yields null so stale output is never displayed.
/// </summary>
public sealed class BackgroundRenderer<TResult>(Func<string, TResult> render)
    where TResult : class
{
    private int _latest;

    /// <returns>The result, or null when superseded by a newer request.</returns>
    public async Task<TResult?> RenderAsync(string markdown)
    {
        var request = Interlocked.Increment(ref _latest);
        var result = await Task.Run(() => render(markdown));
        return request == Volatile.Read(ref _latest) ? result : null;
    }
}

namespace MarkdownEditor.App.Editing;

/// <summary>
/// Settles a window close request against an asynchronous confirmation (e.g. "save unsaved changes?").
/// WPF forbids calling <c>Close()</c> while the window is already closing, so a confirmation that completes
/// synchronously (nothing to save, or "Don't save") settles the request in place; only one that is still
/// pending (saving to disk) cancels the request and closes again once it resolves.
/// </summary>
internal sealed class CloseConfirmation(Func<Task<bool>> confirm, Action close)
{
    private bool _confirmed;

    /// <summary>Call from the window's Closing handler.</summary>
    /// <returns>True when the current close request must be cancelled.</returns>
    public bool ShouldCancel()
    {
        if (_confirmed) return false;
        var pending = confirm();
        if (pending.IsCompleted) return !pending.GetAwaiter().GetResult();
        _ = CloseWhenConfirmedAsync(pending);
        return true;
    }

    private async Task CloseWhenConfirmedAsync(Task<bool> pending)
    {
        if (!await pending) return;
        _confirmed = true;
        close();
    }
}

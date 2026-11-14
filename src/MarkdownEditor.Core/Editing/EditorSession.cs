using MarkdownEditor.Core.Documents;

namespace MarkdownEditor.Core.Editing;

/// <summary>
/// Document lifecycle: new / open / save / save-as / reload, guarding unsaved changes and noticing when
/// another program modifies the file. UI-agnostic so the workflow is unit-testable.
/// </summary>
public sealed class EditorSession(IDocumentStore store, IUserPrompts prompts, IDocumentWatcher watcher)
{
    /// <summary>Operations in progress; a nested one (saving from the unsaved-changes prompt) counts too.</summary>
    private int _operations;

    public MarkdownDocument Document { get; private set; } = new();

    public event EventHandler? DocumentChanged;

    /// <summary>
    /// Hints that the file may have been modified by another program; answer it by calling
    /// <see cref="CheckForExternalChangeAsync"/>. May be raised on any thread.
    /// </summary>
    public event EventHandler? ExternalChangeSuspected
    {
        add => watcher.Changed += value;
        remove => watcher.Changed -= value;
    }

    public Task<bool> NewAsync() => RunAsync(async () =>
    {
        if (!await ConfirmDiscardAsync()) return false;
        Replace(new MarkdownDocument());
        return true;
    });

    public Task<bool> OpenAsync(string? path = null) => RunAsync(async () =>
    {
        if (!await ConfirmDiscardAsync()) return false;
        path ??= prompts.AskOpenPath();
        return path is not null && await LoadAsync(path);
    });

    /// <summary>Re-reads the document from its file, after confirmation if that loses unsaved changes.</summary>
    public Task<bool> ReloadAsync() => RunAsync(async () =>
    {
        if (Document.FilePath is not { } path) return false;
        if (Document.IsDirty && !prompts.AskReloadDiscardingChanges(Document.DisplayName)) return false;
        return await LoadAsync(path);
    });

    /// <summary>
    /// Offers to reload when the file no longer holds what was last loaded or saved. Declining keeps the
    /// editor's text, now unsaved, and the same file content is not offered again.
    /// </summary>
    /// <returns>True when the document was reloaded.</returns>
    public Task<bool> CheckForExternalChangeAsync()
    {
        // Another operation is running (possibly waiting on a prompt): it must not be interleaved with a reload.
        if (_operations > 0 || Document.FilePath is not { } path) return Task.FromResult(false);
        return RunAsync(async () =>
        {
            string diskText;
            try
            {
                diskText = await store.ReadAsync(path);
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                return false; // deleted, or still being written: the next check picks it up
            }
            if (Document.MatchesSaved(diskText)) return false;

            var hadUnsavedChanges = Document.IsDirty;
            Document.MarkChangedOnDisk(diskText);
            return prompts.AskReloadChangedFile(hadUnsavedChanges) && await LoadAsync(path);
        });
    }

    public Task<bool> SaveAsync() => RunAsync(() =>
        Document.FilePath is null ? SaveAsAsync() : WriteAsync(Document.FilePath));

    public Task<bool> SaveAsAsync() => RunAsync(async () =>
    {
        var suggested = Document.FilePath is null
            ? MarkdownDocument.UntitledName + DocumentFileTypes.DefaultExtension
            : Path.GetFileName(Document.FilePath);
        var path = prompts.AskSavePath(suggested);
        return path is not null && await WriteAsync(path);
    });

    /// <returns>True when it is safe to discard the current document (e.g. on close).</returns>
    public Task<bool> ConfirmDiscardAsync() => RunAsync(async () =>
    {
        if (!Document.IsDirty) return true;
        return prompts.AskUnsavedChanges(Document.DisplayName) switch
        {
            UnsavedChangesDecision.Save => await SaveAsync(),
            UnsavedChangesDecision.Discard => true,
            _ => false,
        };
    });

    private async Task<bool> RunAsync(Func<Task<bool>> operation)
    {
        _operations++;
        try
        {
            return await operation();
        }
        finally
        {
            _operations--;
        }
    }

    private async Task<bool> LoadAsync(string path)
    {
        try
        {
            var text = await store.ReadAsync(path);
            Replace(new MarkdownDocument(Path.GetFullPath(path), text));
            return true;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            prompts.ShowError($"Could not open '{path}': {ex.Message}");
            return false;
        }
    }

    private async Task<bool> WriteAsync(string path)
    {
        try
        {
            await store.WriteAsync(path, Document.Text);
            Document.MarkSaved(Path.GetFullPath(path));
            OnDocumentChanged();
            return true;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            prompts.ShowError($"Could not save '{path}': {ex.Message}");
            return false;
        }
    }

    private void Replace(MarkdownDocument document)
    {
        Document = document;
        OnDocumentChanged();
    }

    private void OnDocumentChanged()
    {
        watcher.Watch(Document.FilePath);
        DocumentChanged?.Invoke(this, EventArgs.Empty);
    }
}

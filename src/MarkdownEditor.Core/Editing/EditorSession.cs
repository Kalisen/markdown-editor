using MarkdownEditor.Core.Documents;

namespace MarkdownEditor.Core.Editing;

/// <summary>
/// Document lifecycle: new / open / save / save-as, guarding unsaved changes.
/// UI-agnostic so the workflow is unit-testable.
/// </summary>
public sealed class EditorSession(IDocumentStore store, IUserPrompts prompts)
{
    public MarkdownDocument Document { get; private set; } = new();

    public event EventHandler? DocumentChanged;

    public async Task<bool> NewAsync()
    {
        if (!await ConfirmDiscardAsync()) return false;
        Replace(new MarkdownDocument());
        return true;
    }

    public async Task<bool> OpenAsync(string? path = null)
    {
        if (!await ConfirmDiscardAsync()) return false;
        path ??= prompts.AskOpenPath();
        if (path is null) return false;
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

    public Task<bool> SaveAsync() =>
        Document.FilePath is null ? SaveAsAsync() : WriteAsync(Document.FilePath);

    public async Task<bool> SaveAsAsync()
    {
        var suggested = Document.FilePath is null
            ? MarkdownDocument.UntitledName + DocumentFileTypes.DefaultExtension
            : Path.GetFileName(Document.FilePath);
        var path = prompts.AskSavePath(suggested);
        return path is not null && await WriteAsync(path);
    }

    /// <returns>True when it is safe to discard the current document (e.g. on close).</returns>
    public async Task<bool> ConfirmDiscardAsync()
    {
        if (!Document.IsDirty) return true;
        return prompts.AskUnsavedChanges(Document.DisplayName) switch
        {
            UnsavedChangesDecision.Save => await SaveAsync(),
            UnsavedChangesDecision.Discard => true,
            _ => false,
        };
    }

    private async Task<bool> WriteAsync(string path)
    {
        try
        {
            await store.WriteAsync(path, Document.Text);
            Document.MarkSaved(Path.GetFullPath(path));
            DocumentChanged?.Invoke(this, EventArgs.Empty);
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
        DocumentChanged?.Invoke(this, EventArgs.Empty);
    }
}

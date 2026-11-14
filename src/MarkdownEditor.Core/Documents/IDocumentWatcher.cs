namespace MarkdownEditor.Core.Documents;

/// <summary>Signals that the watched document file may have been modified by another program.</summary>
public interface IDocumentWatcher
{
    /// <summary>
    /// Raised when the watched file was touched. It is only a hint: it also fires for the app's own saves and
    /// may fire several times per change, on any thread.
    /// </summary>
    event EventHandler? Changed;

    /// <summary>Watches <paramref name="path"/> instead of the previous file; null stops watching.</summary>
    void Watch(string? path);
}

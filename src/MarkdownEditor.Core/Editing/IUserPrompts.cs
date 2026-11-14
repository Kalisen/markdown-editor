namespace MarkdownEditor.Core.Editing;

/// <summary>User interactions required by the editing workflow (implemented by the UI layer).</summary>
public interface IUserPrompts
{
    /// <returns>The chosen path, or null if cancelled.</returns>
    string? AskOpenPath();

    /// <returns>The chosen path, or null if cancelled.</returns>
    string? AskSavePath(string suggestedName);

    /// <returns>The chosen export path, or null if cancelled.</returns>
    string? AskExportPath(string suggestedName, Export.ExportFormat format);

    UnsavedChangesDecision AskUnsavedChanges(string documentName);

    /// <summary>Tells the user the file was modified by another program.</summary>
    /// <param name="hasUnsavedChanges">True when reloading would lose edits made in the editor.</param>
    /// <returns>True to reload the file, false to keep the editor's text.</returns>
    bool AskReloadChangedFile(bool hasUnsavedChanges);

    /// <summary>Confirms a reload the user asked for while the document has unsaved changes.</summary>
    /// <returns>True to reload and lose the changes.</returns>
    bool AskReloadDiscardingChanges(string documentName);

    void ShowError(string message);
}

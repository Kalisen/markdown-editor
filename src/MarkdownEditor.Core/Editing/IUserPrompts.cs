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

    void ShowError(string message);
}

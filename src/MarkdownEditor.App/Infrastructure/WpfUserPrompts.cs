using System.Windows;
using MarkdownEditor.Core.Documents;
using MarkdownEditor.Core.Editing;
using Microsoft.Win32;

namespace MarkdownEditor.App.Infrastructure;

internal sealed class WpfUserPrompts : IUserPrompts
{
    private const string AppTitle = "Markdown Editor";

    public string? AskOpenPath()
    {
        var dialog = new OpenFileDialog { Filter = DocumentFileTypes.DialogFilter };
        return dialog.ShowDialog() == true ? dialog.FileName : null;
    }

    public string? AskSavePath(string suggestedName)
    {
        var dialog = new SaveFileDialog
        {
            Filter = DocumentFileTypes.DialogFilter,
            FileName = suggestedName,
            DefaultExt = DocumentFileTypes.DefaultExtension,
        };
        return dialog.ShowDialog() == true ? dialog.FileName : null;
    }

    public UnsavedChangesDecision AskUnsavedChanges(string documentName) =>
        MessageBox.Show($"Save changes to {documentName}?", AppTitle, MessageBoxButton.YesNoCancel, MessageBoxImage.Warning) switch
        {
            MessageBoxResult.Yes => UnsavedChangesDecision.Save,
            MessageBoxResult.No => UnsavedChangesDecision.Discard,
            _ => UnsavedChangesDecision.Cancel,
        };

    public void ShowError(string message) =>
        MessageBox.Show(message, AppTitle, MessageBoxButton.OK, MessageBoxImage.Error);
}

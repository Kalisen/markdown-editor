using System.Windows;
using System.Windows.Controls;
using MarkdownEditor.Core.Documents;
using MarkdownEditor.Core.Editing;
using MarkdownEditor.Core.Export;
using Microsoft.Win32;

namespace MarkdownEditor.App.Infrastructure;

internal sealed class WpfUserPrompts : IUserPrompts
{
    private const string AppTitle = "Markdown Editor";
    private const string FileChangedMessage = "The file has changed on the disk.";
    private const string ReloadLabel = "_Reload";
    private const string CancelLabel = "_Cancel";
    private const double DialogButtonWidth = 88;
    private const double DialogTextWidth = 420;

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

    public string? AskExportPath(string suggestedName, ExportFormat format)
    {
        var dialog = new SaveFileDialog
        {
            Filter = ExportFormats.DialogFilter(format),
            FileName = suggestedName,
            DefaultExt = ExportFormats.Extension(format),
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

    public bool AskReloadChangedFile(bool hasUnsavedChanges) =>
        AskReload(hasUnsavedChanges
            ? $"{FileChangedMessage}\n\nReloading discards your unsaved changes."
            : FileChangedMessage);

    public bool AskReloadDiscardingChanges(string documentName) =>
        AskReload($"Reload {documentName} and discard your unsaved changes?");

    public void ShowError(string message) =>
        MessageBox.Show(message, AppTitle, MessageBoxButton.OK, MessageBoxImage.Error);

    /// <summary>A message box with Reload / Cancel buttons, which <see cref="MessageBox"/> cannot label.</summary>
    private static bool AskReload(string message)
    {
        var reload = new Button { Content = ReloadLabel, IsDefault = true, MinWidth = DialogButtonWidth, Margin = new Thickness(0, 0, 8, 0) };
        var cancel = new Button { Content = CancelLabel, IsCancel = true, MinWidth = DialogButtonWidth };
        var buttons = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Right,
            Margin = new Thickness(0, 20, 0, 0),
            Children = { reload, cancel },
        };
        var dialog = new Window
        {
            Title = AppTitle,
            Content = new StackPanel
            {
                Margin = new Thickness(20),
                Children = { new TextBlock { Text = message, MaxWidth = DialogTextWidth, TextWrapping = TextWrapping.Wrap }, buttons },
            },
            SizeToContent = SizeToContent.WidthAndHeight,
            ResizeMode = ResizeMode.NoResize,
            ShowInTaskbar = false,
            WindowStartupLocation = WindowStartupLocation.CenterScreen,
        };
        if (Application.Current.MainWindow is { IsVisible: true } owner)
        {
            dialog.Owner = owner;
            dialog.WindowStartupLocation = WindowStartupLocation.CenterOwner;
        }
        reload.Click += (_, _) => dialog.DialogResult = true;
        return dialog.ShowDialog() == true;
    }
}

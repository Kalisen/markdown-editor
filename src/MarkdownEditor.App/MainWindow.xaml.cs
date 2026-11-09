using System.ComponentModel;
using System.IO;
using System.Text;
using System.Windows;
using System.Windows.Input;
using System.Windows.Threading;
using MarkdownEditor.App.Editing;
using MarkdownEditor.App.Preview;
using MarkdownEditor.Core.Editing;
using MarkdownEditor.Core.Export;
using MarkdownEditor.Core.Plugins;
using MarkdownEditor.Core.Rendering;

namespace MarkdownEditor.App;

public partial class MainWindow : Window
{
    private const string AppTitle = "Markdown Editor";
    private const string DirtyMarker = "*";
    private static readonly TimeSpan RenderDebounce = TimeSpan.FromMilliseconds(300);
    private const int UndoLimit = 2000;

    private readonly EditorSession _session;
    private readonly IUserPrompts _prompts;
    private readonly BackgroundRenderer _renderer;
    private readonly IReadOnlyList<LoadedPlugin> _plugins;
    private readonly IReadOnlyList<PluginLoadFailure> _failures;
    private readonly PreviewHost _preview;
    private readonly PreviewTheme _theme;
    private readonly DispatcherTimer _renderTimer;
    private bool _loadingDocument;
    private bool _closeConfirmed;

    /// <summary>
    /// True when the editor holds edits not yet copied into the document model. The full text is only
    /// materialized when rendering or before a document operation, not on every keystroke.
    /// </summary>
    private bool _editorAhead;

    internal MainWindow(EditorSession session, IUserPrompts prompts, MarkdownRenderer renderer, IReadOnlyList<LoadedPlugin> plugins,
        IReadOnlyList<PluginLoadFailure> failures, PreviewTheme theme)
    {
        InitializeComponent();
        _session = session;
        _prompts = prompts;
        _theme = theme;
        _renderer = new BackgroundRenderer(renderer.Render);
        _plugins = plugins;
        _failures = failures;

        Editor.SyntaxHighlighting = MarkdownHighlighting.Load();
        Editor.Document.UndoStack.SizeLimit = UndoLimit;
        _preview = new PreviewHost(Preview, plugins, theme);
        _preview.Ready += (_, _) => RenderNow();
        _renderTimer = new DispatcherTimer { Interval = RenderDebounce };
        _renderTimer.Tick += (_, _) => RenderNow();

        Editor.TextChanged += OnEditorTextChanged;
        Editor.TextArea.TextView.ScrollOffsetChanged += (_, _) => SyncScroll();
        _session.DocumentChanged += (_, _) => LoadDocument();
        Drop += OnDrop;
        _preview.OpenDocumentRequested += async (_, path) => await RunSessionAsync(() => _session.OpenAsync(path));
        StateChanged += (_, _) => _preview.SetBackground(WindowState == WindowState.Minimized);
        Activated += (_, _) => _preview.SetBackground(false);
        Deactivated += (_, _) => _preview.SetBackground(true);
        Loaded += async (_, _) =>
        {
            if (await _preview.InitializeAsync() is { } error)
                StatusText.Content = $"Preview unavailable: {error}";
        };

        LoadDocument();
        StatusText.Content = failures.Count == 0
            ? $"{plugins.Count} plugin(s) loaded"
            : $"{plugins.Count} plugin(s) loaded, {failures.Count} failed (Help > Plugins)";
    }

    private void LoadDocument()
    {
        _loadingDocument = true;
        if (Editor.Text != _session.Document.Text) Editor.Text = _session.Document.Text;
        _loadingDocument = false;
        _editorAhead = false;
        _preview.SetDocumentFolder(_session.Document.Directory);
        UpdateTitle();
        RenderNow();
    }

    private void OnEditorTextChanged(object? sender, EventArgs e)
    {
        if (_loadingDocument) return;
        if (!_editorAhead)
        {
            _editorAhead = true;
            UpdateTitle();
        }
        _renderTimer.Stop();
        _renderTimer.Start();
    }

    private void SyncText()
    {
        if (!_editorAhead) return;
        _session.Document.Text = Editor.Text;
        _editorAhead = false;
    }

    private async void RenderNow()
    {
        _renderTimer.Stop();
        SyncText();
        UpdateTitle();
        if (await _renderer.RenderAsync(_session.Document.Text) is { } html) _preview.Render(html);
    }

    /// <summary>Runs a document operation on up-to-date text, then refreshes the title.</summary>
    private async Task RunSessionAsync(Func<Task<bool>> operation)
    {
        SyncText();
        await operation();
        UpdateTitle();
    }

    private void SyncScroll()
    {
        var view = Editor.TextArea.TextView;
        var scrollable = view.DocumentHeight - view.ActualHeight;
        if (scrollable > 0) _preview.ScrollTo(view.VerticalOffset / scrollable);
    }

    private void UpdateTitle()
    {
        var doc = _session.Document;
        Title = $"{doc.DisplayName}{(_editorAhead || doc.IsDirty ? DirtyMarker : string.Empty)} - {AppTitle}";
    }

    private async void OnNew(object sender, ExecutedRoutedEventArgs e) => await RunSessionAsync(_session.NewAsync);

    private async void OnOpen(object sender, ExecutedRoutedEventArgs e) => await RunSessionAsync(() => _session.OpenAsync());

    private async void OnSave(object sender, ExecutedRoutedEventArgs e)
    {
        await RunSessionAsync(_session.SaveAsync);
    }

    private async void OnSaveAs(object sender, ExecutedRoutedEventArgs e)
    {
        await RunSessionAsync(_session.SaveAsAsync);
    }

    private void OnExit(object sender, RoutedEventArgs e) => Close();

    private async void OnExportHtml(object sender, RoutedEventArgs e) => await ExportAsync(ExportFormat.Html);

    private async void OnExportPdf(object sender, RoutedEventArgs e) => await ExportAsync(ExportFormat.Pdf);

    private async Task ExportAsync(ExportFormat format)
    {
        var name = Path.GetFileNameWithoutExtension(_session.Document.DisplayName);
        if (_prompts.AskExportPath(name + ExportFormats.Extension(format), format) is not { } path) return;
        RenderNow(); // export what the editor currently shows
        try
        {
            var exported = format switch
            {
                ExportFormat.Pdf => await _preview.PrintToPdfAsync(path),
                _ => await ExportHtmlAsync(path, name),
            };
            if (exported) StatusText.Content = $"Exported to {path}";
            else _prompts.ShowError("The preview is not ready yet; try exporting again in a moment.");
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            _prompts.ShowError($"Could not export to '{path}': {ex.Message}");
        }
    }

    private async Task<bool> ExportHtmlAsync(string path, string title)
    {
        if (await _preview.SnapshotAsync() is not { } snapshot) return false;
        var resolver = _preview.AssetResolver;
        var html = HtmlExportBuilder.Build(title, snapshot, _theme,
            url => resolver.Resolve(url) is { } file && File.Exists(file) ? File.ReadAllText(file) : null);
        await File.WriteAllTextAsync(path, html);
        return true;
    }

    private async void OnDrop(object sender, DragEventArgs e)
    {
        if (e.Data.GetData(DataFormats.FileDrop) is string[] { Length: > 0 } files)
            await RunSessionAsync(() => _session.OpenAsync(files[0]));
    }

    protected override async void OnClosing(CancelEventArgs e)
    {
        base.OnClosing(e);
        if (_closeConfirmed) return;
        e.Cancel = true;
        SyncText();
        if (!await _session.ConfirmDiscardAsync()) return;
        _closeConfirmed = true;
        Close();
    }

    private void OnShowPlugins(object sender, RoutedEventArgs e)
    {
        var text = new StringBuilder();
        foreach (var p in _plugins)
            text.AppendLine($"{p.Plugin.Name} ({p.Plugin.Id}) v{p.Plugin.Version}");
        if (_plugins.Count == 0) text.AppendLine("No plugins loaded.");
        if (_failures.Count > 0)
        {
            text.AppendLine().AppendLine("Failed:");
            foreach (var f in _failures) text.AppendLine($"{f.Source}: {f.Reason}");
        }
        MessageBox.Show(this, text.ToString(), "Plugins", MessageBoxButton.OK, MessageBoxImage.Information);
    }
}

using System.ComponentModel;
using System.IO;
using System.Text;
using System.Windows;
using System.Windows.Input;
using System.Windows.Threading;
using MarkdownEditor.App.Editing;
using MarkdownEditor.App.Preview;
using MarkdownEditor.App.Scrolling;
using MarkdownEditor.Core.Editing;
using MarkdownEditor.Core.Export;
using MarkdownEditor.Core.Plugins;
using MarkdownEditor.Core.Rendering;
using MarkdownEditor.Plugins.Abstractions;

namespace MarkdownEditor.App;

public partial class MainWindow : Window
{
    private const string AppTitle = "Markdown Editor";
    private const string DirtyMarker = "*";
    private static readonly TimeSpan RenderDebounce = TimeSpan.FromMilliseconds(300);
    private const int UndoLimit = 2000;

    /// <summary>Lets a burst of file events (one save usually raises several) settle into a single check.</summary>
    private static readonly TimeSpan ExternalChangeDebounce = TimeSpan.FromMilliseconds(250);

    public static readonly RoutedUICommand ReloadFileCommand = new("_Reload File", nameof(ReloadFileCommand),
        typeof(MainWindow), [new KeyGesture(Key.F5)]);

    private readonly EditorSession _session;
    private readonly IUserPrompts _prompts;
    private readonly BackgroundRenderer<RenderResult> _renderer;
    private readonly IReadOnlyList<LoadedPlugin> _plugins;
    private readonly IReadOnlyList<PluginLoadFailure> _failures;
    private readonly PreviewHost _preview;
    private readonly PreviewTheme _theme;
    private readonly DispatcherTimer _renderTimer;
    private readonly CloseConfirmation _closeConfirmation;
    private readonly ScrollSynchronizer _scrollSync;
    private readonly DispatcherTimer _externalChangeTimer;
    private bool _loadingDocument;

    /// <summary>The file shown in the editor, to keep the caret and scroll position when it is reloaded.</summary>
    private string? _loadedPath;

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
        _renderer = new BackgroundRenderer<RenderResult>(text => renderer.RenderDocument(text, annotateSourceLines: true));
        _plugins = plugins;
        _failures = failures;
        _closeConfirmation = new CloseConfirmation(() =>
        {
            SyncText();
            return _session.ConfirmDiscardAsync();
        }, Close);

        Editor.SyntaxHighlighting = MarkdownHighlighting.Load();
        Editor.Document.UndoStack.SizeLimit = UndoLimit;
        _preview = new PreviewHost(Preview, plugins, theme);
        _preview.Ready += (_, _) => RenderNow();
        _renderTimer = new DispatcherTimer { Interval = RenderDebounce };
        _renderTimer.Tick += (_, _) => RenderNow();

        Editor.TextChanged += OnEditorTextChanged;
        _scrollSync = new ScrollSynchronizer(_preview.ScrollTo,
            position => Editor.ScrollToVerticalOffset(EditorLineGeometry.OffsetOf(Editor.TextArea.TextView, position)));
        Editor.PreviewMouseWheel += (_, _) => _scrollSync.OnEditorInput();
        Editor.PreviewMouseDown += (_, _) => _scrollSync.OnEditorInput(); // includes dragging the scrollbar
        Editor.PreviewKeyDown += (_, _) => _scrollSync.OnEditorInput();
        Editor.PreviewTouchDown += (_, _) => _scrollSync.OnEditorInput();
        Editor.PreviewStylusDown += (_, _) => _scrollSync.OnEditorInput();
        Editor.TextArea.TextView.ScrollOffsetChanged += (_, _) =>
            _scrollSync.OnEditorScrolled(EditorLineGeometry.PositionOf(Editor.TextArea.TextView));
        _preview.Scrolled += (_, position) => _scrollSync.OnPreviewScrolled(position);
        _session.DocumentChanged += (_, _) => LoadDocument();
        Drop += OnDrop;
        _preview.OpenDocumentRequested += async (_, path) => await RunSessionAsync(() => _session.OpenAsync(path));
        StateChanged += (_, _) => _preview.SetBackground(WindowState == WindowState.Minimized);
        Activated += (_, _) => _preview.SetBackground(false);

        // The prompt waits until the window is in use: file events only trigger a check while it is active,
        // and activation always checks (which also covers changes the file watcher missed).
        _externalChangeTimer = new DispatcherTimer { Interval = ExternalChangeDebounce };
        _externalChangeTimer.Tick += async (_, _) =>
        {
            _externalChangeTimer.Stop();
            if (IsActive) await CheckForExternalChangeAsync();
        };
        _session.ExternalChangeSuspected += (_, _) => Dispatcher.BeginInvoke(() =>
        {
            _externalChangeTimer.Stop();
            _externalChangeTimer.Start();
        });
        Activated += async (_, _) => await CheckForExternalChangeAsync();
        Deactivated += (_, _) => _preview.SetBackground(true);
        Loaded += async (_, _) =>
        {
            if (await _preview.InitializeAsync() is { } error)
                StatusText.Content = $"Preview unavailable: {error}";
        };

        LoadDocument();
        PluginSummary.Content = failures.Count == 0
            ? $"{plugins.Count} plugin(s) loaded"
            : $"{plugins.Count} plugin(s) loaded, {failures.Count} failed (Help > Plugins)";
    }

    private void LoadDocument()
    {
        var document = _session.Document;
        var reloaded = document.FilePath is not null && document.FilePath == _loadedPath;
        _loadedPath = document.FilePath;
        _loadingDocument = true;
        if (Editor.Text != document.Text)
        {
            var caret = Editor.CaretOffset;
            var scroll = Editor.VerticalOffset;
            Editor.Text = document.Text;
            if (reloaded)
            {
                Editor.CaretOffset = Math.Min(caret, Editor.Document.TextLength);
                Editor.ScrollToVerticalOffset(scroll);
            }
        }
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
        if (await _renderer.RenderAsync(_session.Document.Text) is not { } result) return;
        _preview.Render(result.Html);
        ShowUsedExtensions(result.UsedPlugins);
    }

    /// <summary>Runs a document operation on up-to-date text, then refreshes the title.</summary>
    private async Task<bool> RunSessionAsync(Func<Task<bool>> operation)
    {
        SyncText();
        var done = await operation();
        UpdateTitle();
        return done;
    }

    private async Task CheckForExternalChangeAsync()
    {
        if (await RunSessionAsync(_session.CheckForExternalChangeAsync)) ShowReloaded();
    }

    private void ShowReloaded() => StatusText.Content = $"Reloaded {_session.Document.DisplayName}";

    /// <summary>Status bar: the extensions applying to the current document; tooltip lists all loaded plugins.</summary>
    private void ShowUsedExtensions(IReadOnlyList<IMarkdownPlugin> used)
    {
        ActiveExtensions.Text = PluginUsageText.Describe(used);
        ActiveExtensions.ToolTip = PluginUsageText.Details(_plugins.Select(p => p.Plugin), used);
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

    private async void OnReloadFile(object sender, ExecutedRoutedEventArgs e)
    {
        if (await RunSessionAsync(_session.ReloadAsync)) ShowReloaded();
    }

    private void OnCanReloadFile(object sender, CanExecuteRoutedEventArgs e) =>
        e.CanExecute = _session.Document.FilePath is not null;

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

    protected override void OnClosing(CancelEventArgs e)
    {
        base.OnClosing(e);
        e.Cancel = _closeConfirmation.ShouldCancel();
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

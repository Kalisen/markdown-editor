using System.ComponentModel;
using System.Text;
using System.Windows;
using System.Windows.Input;
using System.Windows.Threading;
using MarkdownEditor.App.Editing;
using MarkdownEditor.App.Preview;
using MarkdownEditor.Core.Editing;
using MarkdownEditor.Core.Plugins;
using MarkdownEditor.Core.Rendering;

namespace MarkdownEditor.App;

public partial class MainWindow : Window
{
    private const string AppTitle = "Markdown Editor";
    private const string DirtyMarker = "*";
    private static readonly TimeSpan RenderDebounce = TimeSpan.FromMilliseconds(300);

    private readonly EditorSession _session;
    private readonly MarkdownRenderer _renderer;
    private readonly IReadOnlyList<LoadedPlugin> _plugins;
    private readonly IReadOnlyList<PluginLoadFailure> _failures;
    private readonly PreviewHost _preview;
    private readonly DispatcherTimer _renderTimer;
    private bool _loadingDocument;
    private bool _closeConfirmed;

    internal MainWindow(EditorSession session, MarkdownRenderer renderer, IReadOnlyList<LoadedPlugin> plugins,
        IReadOnlyList<PluginLoadFailure> failures, PreviewTheme theme)
    {
        InitializeComponent();
        _session = session;
        _renderer = renderer;
        _plugins = plugins;
        _failures = failures;

        Editor.SyntaxHighlighting = MarkdownHighlighting.Load();
        _preview = new PreviewHost(Preview, plugins, theme);
        _preview.Ready += (_, _) => RenderNow();
        _renderTimer = new DispatcherTimer { Interval = RenderDebounce };
        _renderTimer.Tick += (_, _) => RenderNow();

        Editor.TextChanged += OnEditorTextChanged;
        Editor.TextArea.TextView.ScrollOffsetChanged += (_, _) => SyncScroll();
        _session.DocumentChanged += (_, _) => LoadDocument();
        Drop += OnDrop;
        _preview.OpenDocumentRequested += async (_, path) => await _session.OpenAsync(path);
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
        _preview.SetDocumentFolder(_session.Document.Directory);
        UpdateTitle();
        RenderNow();
    }

    private void OnEditorTextChanged(object? sender, EventArgs e)
    {
        if (_loadingDocument) return;
        _session.Document.Text = Editor.Text;
        UpdateTitle();
        _renderTimer.Stop();
        _renderTimer.Start();
    }

    private void RenderNow()
    {
        _renderTimer.Stop();
        _preview.Render(_renderer.Render(_session.Document.Text));
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
        Title = $"{doc.DisplayName}{(doc.IsDirty ? DirtyMarker : string.Empty)} - {AppTitle}";
    }

    private async void OnNew(object sender, ExecutedRoutedEventArgs e) => await _session.NewAsync();

    private async void OnOpen(object sender, ExecutedRoutedEventArgs e) => await _session.OpenAsync();

    private async void OnSave(object sender, ExecutedRoutedEventArgs e)
    {
        if (await _session.SaveAsync()) UpdateTitle();
    }

    private async void OnSaveAs(object sender, ExecutedRoutedEventArgs e)
    {
        if (await _session.SaveAsAsync()) UpdateTitle();
    }

    private void OnExit(object sender, RoutedEventArgs e) => Close();

    private async void OnDrop(object sender, DragEventArgs e)
    {
        if (e.Data.GetData(DataFormats.FileDrop) is string[] { Length: > 0 } files)
            await _session.OpenAsync(files[0]);
    }

    protected override async void OnClosing(CancelEventArgs e)
    {
        base.OnClosing(e);
        if (_closeConfirmed) return;
        e.Cancel = true;
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

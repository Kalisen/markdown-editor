using System.Diagnostics;
using System.IO;
using System.Text.Json;
using MarkdownEditor.App.Infrastructure;
using MarkdownEditor.Core.Documents;
using MarkdownEditor.Core.Export;
using MarkdownEditor.Core.Plugins;
using MarkdownEditor.Core.Rendering;
using MarkdownEditor.Plugins.Abstractions.Preview;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.Wpf;

namespace MarkdownEditor.App.Preview;

/// <summary>
/// Owns the WebView2 preview: serves the shell page, plugin folders and the document folder
/// through virtual hosts, and pushes rendered HTML via web messages (no page reloads).
/// </summary>
internal sealed class PreviewHost(WebView2 view, IReadOnlyList<LoadedPlugin> plugins, PreviewTheme theme)
{
    /// <summary>Smallest change of a scroll position worth sending to the page (in lines, or tail progress).</summary>
    private const double ScrollEpsilon = 0.001;

    private readonly MarkdownFileLocator _locator = new();
    private bool _ready;
    private ScrollPosition? _lastScroll;
    private string? _pendingHtml;
    private string? _documentFolder;

    public event EventHandler? Ready;

    /// <summary>Raised when a preview link targets a Markdown file in the document folder.</summary>
    public event EventHandler<string>? OpenDocumentRequested;

    /// <summary>Raised when user input scrolls the preview.</summary>
    public event EventHandler<ScrollPosition>? Scrolled;

    /// <returns>Null on success, otherwise the reason the preview is unavailable.</returns>
    public async Task<string?> InitializeAsync()
    {
        try
        {
            var env = await CoreWebView2Environment.CreateAsync(userDataFolder: AppPaths.WebViewData);
            await view.EnsureCoreWebView2Async(env);
        }
        catch (Exception ex) // runtime missing, blocked user-data folder, browser process failure...
        {
            return ex.Message;
        }

        var core = view.CoreWebView2;
        Directory.CreateDirectory(AppPaths.PreviewFolder);
        foreach (var (name, content) in PreviewPageBuilder.Build(theme, plugins.Select(p => p.Plugin)).Files)
            await File.WriteAllTextAsync(Path.Combine(AppPaths.PreviewFolder, name), content);
        core.SetVirtualHostNameToFolderMapping(PreviewHosts.AppHost, AppPaths.PreviewFolder, CoreWebView2HostResourceAccessKind.Allow);
        foreach (var p in plugins)
            core.SetVirtualHostNameToFolderMapping(PreviewHosts.PluginHost(p.Plugin.Id), p.Folder, CoreWebView2HostResourceAccessKind.Allow);
        MapDocumentFolder();

        Harden(core.Settings);
        core.WebMessageReceived += OnWebMessage;
        core.NewWindowRequested += (_, e) =>
        {
            e.Handled = true;
            Follow(e.Uri);
        };
        core.NavigationStarting += OnNavigationStarting;
        core.Navigate(ShellUrl);
        return null;
    }

    private static string ShellUrl => PreviewHosts.AppOrigin + PreviewPageBuilder.PageFileName;

    private static void Harden(CoreWebView2Settings settings)
    {
        settings.IsStatusBarEnabled = false;
        settings.AreHostObjectsAllowed = false;
        settings.IsPasswordAutosaveEnabled = false;
        settings.IsGeneralAutofillEnabled = false;
#if !DEBUG
        settings.AreDevToolsEnabled = false;
        settings.AreBrowserAcceleratorKeysEnabled = false;
#endif
    }

    /// <summary>The preview only ever shows the shell page; any other navigation is treated as a link click.</summary>
    private void OnNavigationStarting(object? sender, CoreWebView2NavigationStartingEventArgs e)
    {
        if (string.Equals(e.Uri, ShellUrl, StringComparison.OrdinalIgnoreCase)) return;
        e.Cancel = true;
        if (e.IsUserInitiated) Follow(e.Uri);
    }

    /// <summary>Script evaluated in the page (host-side, not subject to the page CSP) to capture the rendered preview.</summary>
    private const string SnapshotScript =
        "JSON.stringify({ html: document.getElementById('" + PreviewPageBuilder.ContentElementId + "').innerHTML, " +
        "styles: Array.from(document.querySelectorAll('link[rel=stylesheet]'), l => l.href) })";

    /// <returns>The rendered content and stylesheet URLs, or null when the preview is not ready.</returns>
    public async Task<PreviewSnapshot?> SnapshotAsync()
    {
        if (!_ready) return null;
        var json = JsonSerializer.Deserialize<string>(await view.CoreWebView2.ExecuteScriptAsync(SnapshotScript));
        if (json is null) return null;
        using var doc = JsonDocument.Parse(json);
        var styles = doc.RootElement.GetProperty("styles").EnumerateArray().Select(e => e.GetString()!).ToList();
        return new PreviewSnapshot(doc.RootElement.GetProperty("html").GetString() ?? string.Empty, styles);
    }

    /// <summary>Resolves stylesheet URLs of the preview to files (shell folder and plugin folders).</summary>
    public PreviewAssetResolver AssetResolver => new(AppPaths.PreviewFolder, plugins.ToDictionary(p => p.Plugin.Id, p => p.Folder));

    /// <summary>Prints the live preview (print styles force light colours) to a PDF file.</summary>
    public async Task<bool> PrintToPdfAsync(string path)
    {
        if (!_ready) return false;
        var settings = view.CoreWebView2.Environment.CreatePrintSettings();
        settings.ShouldPrintBackgrounds = true;
        settings.ShouldPrintHeaderAndFooter = false;
        return await view.CoreWebView2.PrintToPdfAsync(path, settings);
    }

    public void SetDocumentFolder(string? folder)
    {
        _documentFolder = folder;
        MapDocumentFolder();
    }

    public void Render(string html)
    {
        if (!_ready)
        {
            _pendingHtml = html;
            return;
        }
        view.CoreWebView2.PostWebMessageAsString(html);
    }

    /// <summary>Scrolls the preview to follow the editor's position.</summary>
    public void ScrollTo(ScrollPosition position)
    {
        if (!_ready || _lastScroll is { } last
            && Math.Abs(position.Line - last.Line) < ScrollEpsilon && Math.Abs(position.Tail - last.Tail) < ScrollEpsilon) return;
        _lastScroll = position;
        view.CoreWebView2.PostWebMessageAsJson(PreviewMessages.ScrollToLine(position));
    }

    /// <summary>Lowers WebView2 memory usage while the app is minimized or in the background.</summary>
    public void SetBackground(bool background)
    {
        if (view.CoreWebView2 is { } core)
            core.MemoryUsageTargetLevel = background ? CoreWebView2MemoryUsageTargetLevel.Low : CoreWebView2MemoryUsageTargetLevel.Normal;
    }

    private void MapDocumentFolder()
    {
        var core = view.CoreWebView2;
        if (core is null) return;
        core.ClearVirtualHostNameToFolderMapping(PreviewHosts.DocumentHost);
        if (_documentFolder is not null)
            core.SetVirtualHostNameToFolderMapping(PreviewHosts.DocumentHost, _documentFolder, CoreWebView2HostResourceAccessKind.Allow);
    }

    private void OnWebMessage(object? sender, CoreWebView2WebMessageReceivedEventArgs e)
    {
        if (!string.Equals(e.Source, ShellUrl, StringComparison.OrdinalIgnoreCase)) return;
        switch (PreviewMessages.TryParse(e.WebMessageAsJson))
        {
            case { Kind: PreviewInboundKind.Ready }:
                _ready = true;
                if (_pendingHtml is not null) Render(_pendingHtml);
                _pendingHtml = null;
                Ready?.Invoke(this, EventArgs.Empty);
                break;
            case { Kind: PreviewInboundKind.OpenLink, Href: var href }:
                Follow(href);
                break;
            case { Kind: PreviewInboundKind.Scrolled, Position: { } position }:
                _lastScroll = null; // the page moved on its own; the next request must go through
                Scrolled?.Invoke(this, position);
                break;
        }
    }

    private void Follow(string? href)
    {
        var action = PreviewLinkPolicy.Classify(href, _documentFolder);
        switch (action.Kind)
        {
            case LinkActionKind.OpenExternal:
                Process.Start(new ProcessStartInfo(action.Target!) { UseShellExecute = true });
                break;
            case LinkActionKind.OpenDocument:
                // Missing targets (e.g. wikilinks to notes in other folders) are searched under the document folder.
                OpenDocumentRequested?.Invoke(this, _locator.Locate(action.Target!, _documentFolder) ?? action.Target!);
                break;
        }
    }
}

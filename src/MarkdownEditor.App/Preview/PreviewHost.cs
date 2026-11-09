using System.Diagnostics;
using System.IO;
using MarkdownEditor.App.Infrastructure;
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
    private bool _ready;
    private string? _pendingHtml;
    private string? _documentFolder;

    public event EventHandler? Ready;

    /// <summary>Raised when a preview link targets a Markdown file in the document folder.</summary>
    public event EventHandler<string>? OpenDocumentRequested;

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
        await File.WriteAllTextAsync(Path.Combine(AppPaths.PreviewFolder, AppPaths.PreviewPageName),
            PreviewPageBuilder.Build(theme, plugins.Select(p => p.Plugin)));
        core.SetVirtualHostNameToFolderMapping(PreviewHosts.AppHost, AppPaths.PreviewFolder, CoreWebView2HostResourceAccessKind.Allow);
        foreach (var p in plugins)
            core.SetVirtualHostNameToFolderMapping(PreviewHosts.PluginHost(p.Plugin.Id), p.Folder, CoreWebView2HostResourceAccessKind.Allow);
        MapDocumentFolder();

        core.Settings.IsStatusBarEnabled = false;
        core.WebMessageReceived += OnWebMessage;
        core.NewWindowRequested += (_, e) =>
        {
            e.Handled = true;
            Follow(e.Uri);
        };
        core.Navigate(PreviewHosts.AppOrigin + AppPaths.PreviewPageName);
        return null;
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
        view.CoreWebView2.PostWebMessageAsJson(PreviewMessages.Render(html));
    }

    public void ScrollTo(double ratio)
    {
        if (_ready) view.CoreWebView2.PostWebMessageAsJson(PreviewMessages.Scroll(ratio));
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
                OpenDocumentRequested?.Invoke(this, action.Target!);
                break;
        }
    }
}

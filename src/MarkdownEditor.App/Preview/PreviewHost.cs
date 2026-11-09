using System.Diagnostics;
using System.IO;
using System.Text.Json;
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
    private const string MessageTypeProperty = "type";
    private const string HrefProperty = "href";
    private static readonly HashSet<string> ExternalSchemes = [Uri.UriSchemeHttp, Uri.UriSchemeHttps, Uri.UriSchemeMailto];

    private bool _ready;
    private string? _pendingHtml;
    private string? _documentFolder;

    public event EventHandler? Ready;

    public async Task InitializeAsync()
    {
        var env = await CoreWebView2Environment.CreateAsync(userDataFolder: AppPaths.WebViewData);
        await view.EnsureCoreWebView2Async(env);
        var core = view.CoreWebView2;

        Directory.CreateDirectory(AppPaths.PreviewFolder);
        await File.WriteAllTextAsync(Path.Combine(AppPaths.PreviewFolder, AppPaths.PreviewPageName),
            PreviewPageBuilder.Build(theme, plugins.Select(p => p.Plugin)));
        core.SetVirtualHostNameToFolderMapping(PreviewHosts.AppHost, AppPaths.PreviewFolder, CoreWebView2HostResourceAccessKind.Allow);
        foreach (var p in plugins)
            core.SetVirtualHostNameToFolderMapping(PreviewHosts.PluginHost(p.Plugin.Id), p.Folder, CoreWebView2HostResourceAccessKind.Allow);
        MapDocumentFolder();

        core.Settings.AreDefaultContextMenusEnabled = true;
        core.Settings.IsStatusBarEnabled = false;
        core.WebMessageReceived += OnWebMessage;
        core.NewWindowRequested += (_, e) => { e.Handled = true; OpenExternal(e.Uri); };
        core.Navigate(PreviewHosts.AppOrigin + AppPaths.PreviewPageName);
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
        using var message = JsonDocument.Parse(e.WebMessageAsJson);
        var root = message.RootElement;
        switch (root.GetProperty(MessageTypeProperty).GetString())
        {
            case PreviewMessages.ReadyType:
                _ready = true;
                if (_pendingHtml is not null) Render(_pendingHtml);
                _pendingHtml = null;
                Ready?.Invoke(this, EventArgs.Empty);
                break;
            case PreviewMessages.OpenLinkType:
                OpenExternal(root.GetProperty(HrefProperty).GetString());
                break;
        }
    }

    private static void OpenExternal(string? href)
    {
        if (Uri.TryCreate(href, UriKind.Absolute, out var uri) && ExternalSchemes.Contains(uri.Scheme)
            && !uri.Host.EndsWith(PreviewHosts.PluginHostSuffix, StringComparison.OrdinalIgnoreCase))
            Process.Start(new ProcessStartInfo(uri.AbsoluteUri) { UseShellExecute = true });
    }
}

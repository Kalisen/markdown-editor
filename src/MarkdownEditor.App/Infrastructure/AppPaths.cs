using System.IO;

namespace MarkdownEditor.App.Infrastructure;

internal static class AppPaths
{
    private const string AppFolderName = "MarkdownEditor";
    private const string PreviewFolderName = "preview";
    private const string WebViewDataFolderName = "webview2";
    public const string PreviewPageName = "index.html";

    public static string LocalData { get; } =
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), AppFolderName);

    public static string PreviewFolder => Path.Combine(LocalData, PreviewFolderName);

    public static string WebViewData => Path.Combine(LocalData, WebViewDataFolderName);
}

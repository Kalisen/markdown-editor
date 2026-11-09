using System.Net;
using System.Text;
using MarkdownEditor.Core.Rendering;
using MarkdownEditor.Plugins.Abstractions.Preview;

namespace MarkdownEditor.Core.Export;

/// <summary>The rendered preview as reported by the page: content HTML and the stylesheet URLs in use.</summary>
public sealed record PreviewSnapshot(string ContentHtml, IReadOnlyList<string> StylesheetUrls);

/// <summary>Builds a single, script-free HTML file from a preview snapshot with its stylesheets inlined.</summary>
public static class HtmlExportBuilder
{
    /// <param name="readStylesheet">Returns the CSS text for a stylesheet URL, or null if it cannot be resolved.</param>
    public static string Build(string title, PreviewSnapshot snapshot, PreviewTheme theme, Func<string, string?> readStylesheet)
    {
        var styles = new StringBuilder();
        foreach (var url in snapshot.StylesheetUrls.Distinct())
            if (readStylesheet(url) is { } css)
                styles.Append("<style>/* ").Append(WebUtility.HtmlEncode(url)).Append(" */\n").Append(css.Replace("</style", "<\\/style")).Append("\n</style>\n");

        return $"""
            <!DOCTYPE html>
            <html data-theme="{theme.ToString().ToLowerInvariant()}">
            <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>{WebUtility.HtmlEncode(title)}</title>
            {styles}</head>
            <body>
            <main id="{PreviewPageBuilder.ContentElementId}" class="markdown-body">
            {snapshot.ContentHtml}
            </main>
            </body>
            </html>
            """;
    }
}

/// <summary>Maps preview URLs (app and plugin virtual hosts) back to files on disk.</summary>
public sealed class PreviewAssetResolver(string appFolder, IReadOnlyDictionary<string, string> pluginFolders)
{
    /// <returns>The file path inside the mapped folder, or null for any other URL or a path escaping it.</returns>
    public string? Resolve(string url)
    {
        if (!Uri.TryCreate(url, UriKind.Absolute, out var uri)) return null;
        string? folder = null;
        if (string.Equals(uri.Host, PreviewHosts.AppHost, StringComparison.OrdinalIgnoreCase)) folder = appFolder;
        else if (uri.Host.EndsWith(PreviewHosts.PluginHostSuffix, StringComparison.OrdinalIgnoreCase))
            pluginFolders.TryGetValue(uri.Host[..^PreviewHosts.PluginHostSuffix.Length], out folder);
        if (folder is null) return null;

        var root = Path.GetFullPath(folder);
        var path = Path.GetFullPath(Path.Combine(root, Uri.UnescapeDataString(uri.AbsolutePath).TrimStart('/')));
        return path.StartsWith(Path.TrimEndingDirectorySeparator(root) + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase)
            ? path
            : null;
    }
}

using System.Net;
using System.Reflection;
using System.Text;
using MarkdownEditor.Plugins.Abstractions;
using MarkdownEditor.Plugins.Abstractions.Preview;

namespace MarkdownEditor.Core.Rendering;

/// <summary>The preview shell: file name → content, served from <see cref="PreviewHosts.AppHost"/>.</summary>
public sealed record PreviewPage(IReadOnlyDictionary<string, string> Files);

/// <summary>Builds the preview shell page: base styles, the host script, plugin assets and the CSP.</summary>
public static class PreviewPageBuilder
{
    public const string ContentElementId = "content";
    public const string PageFileName = "index.html";
    public const string ScriptFileName = "preview.js";
    public const string StyleFileName = "preview.css";
    private const string ResourcePrefix = "MarkdownEditor.Core.Rendering.Assets.";

    private static string PluginOrigins => $"{PreviewHosts.Scheme}://*{PreviewHosts.PluginHostSuffix}";

    /// <summary>
    /// Document content is untrusted (CommonMark allows raw HTML): only the app and plugin hosts may
    /// supply script, no inline script/eval, no network access, frames, plugins, forms or base override.
    /// Inline styles are allowed (Mermaid SVGs embed them); images may come from the document or https.
    /// </summary>
    public static string ContentSecurityPolicy =>
        string.Join("; ",
            "default-src 'none'",
            // 'wasm-unsafe-eval' lets bundled plugins compile WebAssembly (Graphviz); it does not allow eval or inline script.
            $"script-src {PreviewHosts.AppOrigin} {PluginOrigins} 'wasm-unsafe-eval'",
            $"style-src {PreviewHosts.AppOrigin} {PluginOrigins} 'unsafe-inline'",
            $"font-src {PluginOrigins} data:",
            "img-src https: data:",
            "connect-src 'none'",
            "frame-src 'none'",
            "object-src 'none'",
            "base-uri 'none'",
            "form-action 'none'");

    public static PreviewPage Build(PreviewTheme theme, IEnumerable<IMarkdownPlugin> plugins)
    {
        var themeName = theme.ToString().ToLowerInvariant();
        var head = new StringBuilder();
        var scripts = new StringBuilder();
        foreach (var plugin in plugins)
        foreach (var asset in plugin.PreviewAssets)
        {
            var url = WebUtility.HtmlEncode(PreviewHosts.PluginOrigin(plugin.Id) + asset.RelativePath.TrimStart('/'));
            if (asset.Kind == PreviewAssetKind.Stylesheet)
                head.AppendLine($"<link rel=\"stylesheet\" href=\"{url}\">");
            else
                scripts.AppendLine($"<script src=\"{url}\"></script>");
        }

        var html = $"""
            <!DOCTYPE html>
            <html data-theme="{themeName}">
            <head>
            <meta charset="utf-8">
            <meta http-equiv="Content-Security-Policy" content="{ContentSecurityPolicy}">
            <link rel="stylesheet" href="{StyleFileName}">
            {head}</head>
            <body>
            <main id="{ContentElementId}" class="markdown-body"></main>
            <script src="{ScriptFileName}"></script>
            {scripts}</body>
            </html>
            """;

        return new PreviewPage(new Dictionary<string, string>
        {
            [PageFileName] = html,
            [ScriptFileName] = ReadAsset(ScriptFileName),
            [StyleFileName] = ReadAsset(StyleFileName),
        });
    }

    internal static string ReadAsset(string name)
    {
        using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream(ResourcePrefix + name)
                           ?? throw new InvalidOperationException($"Missing preview asset {name}");
        using var reader = new StreamReader(stream);
        return reader.ReadToEnd();
    }
}

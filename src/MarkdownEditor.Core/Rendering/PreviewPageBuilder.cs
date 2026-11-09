using System.Net;
using System.Reflection;
using System.Text;
using MarkdownEditor.Plugins.Abstractions;
using MarkdownEditor.Plugins.Abstractions.Preview;

namespace MarkdownEditor.Core.Rendering;

/// <summary>Builds the preview shell page: base styles, the host script, and plugin assets.</summary>
public static class PreviewPageBuilder
{
    public const string ContentElementId = "content";
    private const string ResourcePrefix = "MarkdownEditor.Core.Rendering.Assets.";

    public static string Build(PreviewTheme theme, IEnumerable<IMarkdownPlugin> plugins)
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

        return $"""
            <!DOCTYPE html>
            <html data-theme="{themeName}">
            <head>
            <meta charset="utf-8">
            <style>{ReadAsset("preview.css")}</style>
            {head}</head>
            <body>
            <main id="{ContentElementId}" class="markdown-body"></main>
            <script>{ReadAsset("preview.js")}</script>
            {scripts}<script>window.{PreviewScriptApi.GlobalObject}._ready();</script>
            </body>
            </html>
            """;
    }

    internal static string ReadAsset(string name)
    {
        using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream(ResourcePrefix + name)
                           ?? throw new InvalidOperationException($"Missing preview asset {name}");
        using var reader = new StreamReader(stream);
        return reader.ReadToEnd();
    }
}

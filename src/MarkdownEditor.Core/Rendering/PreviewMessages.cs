using System.Text.Json;

namespace MarkdownEditor.Core.Rendering;

/// <summary>JSON messages exchanged with the preview page (see Assets/preview.js).</summary>
public static class PreviewMessages
{
    public const string RenderType = "render";
    public const string ScrollType = "scroll";
    public const string ReadyType = "ready";
    public const string OpenLinkType = "open-link";

    public static string Render(string html) => JsonSerializer.Serialize(new { type = RenderType, html });

    public static string Scroll(double ratio) =>
        JsonSerializer.Serialize(new { type = ScrollType, ratio = Math.Clamp(ratio, 0d, 1d) });
}

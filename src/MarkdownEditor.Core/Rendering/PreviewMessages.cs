using System.Text.Json;

namespace MarkdownEditor.Core.Rendering;

/// <summary>
/// Messages exchanged with the preview page (see Assets/preview.js). Rendered HTML is posted as a plain
/// string message (no JSON envelope); these JSON messages carry control information.
/// </summary>
public static class PreviewMessages
{
    public const string ScrollType = "scroll";
    public const string ReadyType = "ready";
    public const string OpenLinkType = "open-link";


    public static string Scroll(double ratio) =>
        JsonSerializer.Serialize(new { type = ScrollType, ratio = Math.Clamp(ratio, 0d, 1d) });

    /// <summary>
    /// Parses a message posted by the preview page. Anything malformed or unknown yields null:
    /// page content is untrusted and must never be able to crash the host.
    /// </summary>
    public static PreviewInboundMessage? TryParse(string? json)
    {
        if (string.IsNullOrEmpty(json)) return null;
        try
        {
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;
            if (root.ValueKind != JsonValueKind.Object) return null;
            return ReadString(root, TypeProperty) switch
            {
                ReadyType => new PreviewInboundMessage(PreviewInboundKind.Ready),
                OpenLinkType when ReadString(root, HrefProperty) is { } href => new PreviewInboundMessage(PreviewInboundKind.OpenLink, href),
                _ => null,
            };
        }
        catch (JsonException)
        {
            return null;
        }
    }

    private const string TypeProperty = "type";
    private const string HrefProperty = "href";

    private static string? ReadString(JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() : null;
}

public enum PreviewInboundKind
{
    Ready,
    OpenLink,
}

public sealed record PreviewInboundMessage(PreviewInboundKind Kind, string? Href = null);

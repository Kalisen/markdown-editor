using System.Text.Json;

namespace MarkdownEditor.Core.Rendering;

/// <summary>
/// Messages exchanged with the preview page (see Assets/preview.js). Rendered HTML is posted as a plain
/// string message (no JSON envelope); these JSON messages carry control information.
/// </summary>
public static class PreviewMessages
{
    /// <summary>Host to page: the editor drives; show the given fractional 0-based source line at the top.</summary>
    public const string ScrollToLineType = "scroll-to-line";

    public const string ReadyType = "ready";
    public const string OpenLinkType = "open-link";

    /// <summary>Page to host: the preview drives; its top now shows the given fractional 0-based source line.</summary>
    public const string ScrolledType = "scrolled";

    public static string ScrollToLine(double line) =>
        JsonSerializer.Serialize(new { type = ScrollToLineType, line = Math.Max(0d, line) });

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
                ScrolledType when ReadLine(root) is { } line => new PreviewInboundMessage(PreviewInboundKind.Scrolled, Line: line),
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
    private const string LineProperty = "line";

    private static double? ReadLine(JsonElement element) =>
        element.TryGetProperty(LineProperty, out var value) && value.ValueKind == JsonValueKind.Number
            && value.GetDouble() is var line && double.IsFinite(line) && line >= 0 ? line : null;

    private static string? ReadString(JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() : null;
}

public enum PreviewInboundKind
{
    Ready,
    OpenLink,
    Scrolled,
}

/// <param name="Line">For <see cref="PreviewInboundKind.Scrolled"/>: the fractional 0-based source line at the top of the preview.</param>
public sealed record PreviewInboundMessage(PreviewInboundKind Kind, string? Href = null, double? Line = null);

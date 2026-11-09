using System.Text.RegularExpressions;

namespace MarkdownEditor.Plugin.Images;

/// <summary>Size hint written as an image title: "=WxH", "=Wx" or "=xH" (pixels).</summary>
internal readonly partial record struct ImageSizeHint(int? Width, int? Height)
{
    [GeneratedRegex(@"^=(?<w>\d+)?x(?<h>\d+)?$")]
    private static partial Regex Pattern();

    public static bool TryParse(string? title, out ImageSizeHint hint)
    {
        hint = default;
        if (title is null) return false;
        var match = Pattern().Match(title.Trim());
        if (!match.Success) return false;
        int? Read(string group) => match.Groups[group].Success ? int.Parse(match.Groups[group].Value) : null;
        hint = new ImageSizeHint(Read("w"), Read("h"));
        return hint.Width is not null || hint.Height is not null;
    }
}

using System.Text.RegularExpressions;

namespace MarkdownEditor.Plugins.Abstractions;

/// <summary>Validation rules for plugin identifiers (they are used as preview host names).</summary>
public static partial class PluginId
{
    public const int MaxLength = 40;

    [GeneratedRegex("^[a-z0-9]+(-[a-z0-9]+)*$")]
    private static partial Regex Pattern();

    public static bool IsValid(string? id) =>
        !string.IsNullOrEmpty(id) && id.Length <= MaxLength && Pattern().IsMatch(id);
}

using MarkdownEditor.Plugins.Abstractions;

namespace MarkdownEditor.Core.Plugins;

/// <summary>Status bar wording for the extensions used by the current document.</summary>
public static class PluginUsageText
{
    public const string Label = "Extensions";
    public const string NoneText = "none (CommonMark only)";
    public const string Separator = " · ";

    /// <summary>E.g. "Extensions: Math · Tables (GFM)", in alphabetical order.</summary>
    public static string Describe(IEnumerable<IMarkdownPlugin> used)
    {
        var names = used.Select(p => p.Name).Order(StringComparer.CurrentCultureIgnoreCase).ToList();
        return $"{Label}: {(names.Count == 0 ? NoneText : string.Join(Separator, names))}";
    }

    /// <summary>Tooltip: every loaded plugin, marking those in use.</summary>
    public static string Details(IEnumerable<IMarkdownPlugin> loaded, IEnumerable<IMarkdownPlugin> used)
    {
        var inUse = used.Select(p => p.Id).ToHashSet(StringComparer.Ordinal);
        return string.Join(Environment.NewLine, loaded
            .OrderBy(p => p.Name, StringComparer.CurrentCultureIgnoreCase)
            .Select(p => $"{(inUse.Contains(p.Id) ? "●" : "○")} {p.Name}"));
    }
}

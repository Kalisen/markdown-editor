using System.Text.RegularExpressions;

namespace MarkdownEditor.Plugin.FrontMatter;

/// <summary>A top-level front matter entry: a scalar, a list, or (for nested mappings) raw YAML text.</summary>
public sealed record FrontMatterEntry(string Key, IReadOnlyList<string> Values, bool IsRaw = false);

/// <summary>
/// Minimal YAML reader for front matter tables: top-level <c>key: value</c> scalars, inline lists
/// <c>[a, b]</c> and block lists (<c>- item</c>). Nested mappings are kept as raw text.
/// </summary>
public static partial class FrontMatterYaml
{
    private const string ListItemPrefix = "- ";
    private const char Comment = '#';

    [GeneratedRegex(@"^(?<key>[^\s#:][^:]*?):(?:\s+(?<value>.*))?$")]
    private static partial Regex TopLevelKey();

    public static List<FrontMatterEntry> Parse(string yaml)
    {
        var entries = new List<FrontMatterEntry>();
        var lines = yaml.Replace("\r\n", "\n").Split('\n');
        for (var i = 0; i < lines.Length; i++)
        {
            var match = TopLevelKey().Match(lines[i].TrimEnd());
            if (!match.Success) continue;

            var key = Unquote(match.Groups["key"].Value.Trim());
            var value = StripComment(match.Groups["value"].Value).Trim();
            if (value.Length > 0)
            {
                entries.Add(new FrontMatterEntry(key, IsInlineList(value) ? SplitInlineList(value) : [Unquote(value)]));
                continue;
            }

            var nested = new List<string>();
            while (i + 1 < lines.Length && (lines[i + 1].Length == 0 || char.IsWhiteSpace(lines[i + 1][0]) || lines[i + 1].StartsWith(ListItemPrefix)))
                nested.Add(lines[++i]);
            while (nested.Count > 0 && nested[^1].Trim().Length == 0) nested.RemoveAt(nested.Count - 1);

            var items = nested.Select(l => l.Trim()).Where(l => l.Length > 0).ToList();
            if (items.Count > 0 && items.All(l => l.StartsWith(ListItemPrefix, StringComparison.Ordinal)))
                entries.Add(new FrontMatterEntry(key, items.Select(l => Unquote(StripComment(l[ListItemPrefix.Length..]).Trim())).ToList()));
            else
                entries.Add(new FrontMatterEntry(key, items.Count == 0 ? [] : [Dedent(nested)], IsRaw: items.Count > 0));
        }
        return entries;
    }

    private static bool IsInlineList(string value) => value.StartsWith('[') && value.EndsWith(']');

    private static List<string> SplitInlineList(string value) =>
        value[1..^1].Split(',').Select(v => Unquote(v.Trim())).Where(v => v.Length > 0).ToList();

    private static string Unquote(string value) =>
        value.Length >= 2 && (value[0] == '"' && value[^1] == '"' || value[0] == '\'' && value[^1] == '\'')
            ? value[1..^1]
            : value;

    /// <summary>Removes a trailing <c># comment</c> outside quotes.</summary>
    private static string StripComment(string value)
    {
        var quote = '\0';
        for (var i = 0; i < value.Length; i++)
        {
            var c = value[i];
            if (quote != '\0') { if (c == quote) quote = '\0'; }
            else if (c is '"' or '\'') quote = c;
            else if (c == Comment && (i == 0 || char.IsWhiteSpace(value[i - 1]))) return value[..i];
        }
        return value;
    }

    private static string Dedent(List<string> lines)
    {
        var indent = lines.Where(l => l.Trim().Length > 0).Min(l => l.Length - l.TrimStart().Length);
        return string.Join("\n", lines.Select(l => l.Length >= indent ? l[indent..] : l.TrimStart()));
    }
}

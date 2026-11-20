using System.Text;

namespace MarkdownEditor.Plugin.Tables;

public enum ColumnAlignment
{
    None,
    Left,
    Center,
    Right,
}

/// <summary>Line-level rules of GFM tables (spec 0.29, section 4.10).</summary>
internal static class GfmTableSyntax
{
    private const char Pipe = '|';
    private const char Escape = '\\';
    private const char Dash = '-';
    private const char Colon = ':';
    private const int MaxIndent = 3;

    /// <summary>Splits a row into raw cell texts on unescaped pipes; leading/trailing pipes are optional.</summary>
    public static List<string> SplitCells(string line)
    {
        var text = line.Trim();
        if (text.StartsWith(Pipe)) text = text[1..];
        if (text.EndsWith(Pipe) && !IsEscaped(text, text.Length - 1)) text = text[..^1];

        var cells = new List<string>();
        var current = new StringBuilder();
        for (var i = 0; i < text.Length; i++)
        {
            if (text[i] == Pipe && !IsEscaped(text, i))
            {
                cells.Add(current.ToString().Trim());
                current.Clear();
            }
            else
            {
                current.Append(text[i]);
            }
        }
        cells.Add(current.ToString().Trim());
        return cells;
    }

    /// <summary>GFM: <c>\|</c> inside a cell becomes a literal pipe before inline parsing (also inside code spans).</summary>
    public static string UnescapePipes(string cell) => cell.Replace("\\|", "|", StringComparison.Ordinal);

    /// <returns>The column alignments, or null when the line is not a delimiter row.</returns>
    public static List<ColumnAlignment>? ParseDelimiterRow(string line)
    {
        if (LeadingSpaces(line) > MaxIndent) return null;
        var trimmed = line.Trim();
        if (trimmed.Length == 0 || (!trimmed.Contains(Pipe) && !trimmed.Contains(Colon))) return null;

        var alignments = new List<ColumnAlignment>();
        foreach (var cell in SplitCells(trimmed))
        {
            var left = cell.StartsWith(Colon);
            var right = cell.EndsWith(Colon) && cell.Length > 1;
            var dashes = cell.AsSpan(left ? 1 : 0, cell.Length - (left ? 1 : 0) - (right ? 1 : 0));
            if (dashes.Length == 0 || dashes.ContainsAnyExcept(Dash)) return null;
            alignments.Add((left, right) switch
            {
                (true, true) => ColumnAlignment.Center,
                (true, false) => ColumnAlignment.Left,
                (false, true) => ColumnAlignment.Right,
                _ => ColumnAlignment.None,
            });
        }
        return alignments;
    }

    /// <summary>
    /// GFM: the table ends at the first blank line or at the beginning of another block-level structure.
    /// </summary>
    public static bool StartsOtherBlock(string line)
    {
        if (LeadingSpaces(line) > MaxIndent) return false; // indented code cannot interrupt
        var t = line.TrimStart();
        if (t.Length == 0) return true;
        return t[0] switch
        {
            '>' or '#' => true,
            '`' => t.StartsWith("```", StringComparison.Ordinal),
            '~' => t.StartsWith("~~~", StringComparison.Ordinal),
            '<' => true,
            '*' or '-' or '+' => t.Length == 1 || t[1] == ' ' || IsThematicBreak(t),
            '_' => IsThematicBreak(t),
            _ => IsOrderedListStart(t),
        };
    }

    private static bool IsThematicBreak(string t)
    {
        var compact = t.Replace(" ", "").Replace("\t", "");
        return compact.Length >= 3 && compact.All(c => c == compact[0]) && compact[0] is '*' or '-' or '_';
    }

    private static bool IsOrderedListStart(string t)
    {
        var digits = 0;
        while (digits < t.Length && digits < 10 && char.IsAsciiDigit(t[digits])) digits++;
        return digits is > 0 and < 10 && digits < t.Length && t[digits] is '.' or ')'
               && (digits + 1 == t.Length || t[digits + 1] == ' ');
    }

    private static int LeadingSpaces(string line)
    {
        var n = 0;
        foreach (var c in line)
        {
            if (c == ' ') n++;
            else if (c == '\t') n += 4;
            else break;
        }
        return n;
    }

    private static bool IsEscaped(string text, int index)
    {
        var backslashes = 0;
        for (var i = index - 1; i >= 0 && text[i] == Escape; i--) backslashes++;
        return backslashes % 2 == 1;
    }
}

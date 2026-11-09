namespace MarkdownEditor.Plugin.Autolinks;

/// <param name="Start">Index of the first character in the scanned text.</param>
/// <param name="Length">Length of the linked text.</param>
/// <param name="Url">The link target (scheme added for www and email links).</param>
public readonly record struct AutolinkMatch(int Start, int Length, string Url);

/// <summary>GFM extended autolinks (spec 0.29, section 6.9): www, http(s)/ftp URLs and email addresses.</summary>
public static class GfmAutolinkScanner
{
    private const string WwwPrefix = "www.";
    private const string DefaultScheme = "http://";
    private const string MailtoScheme = "mailto:";
    private static readonly string[] SchemePrefixes = ["http://", "https://", "ftp://"];
    private const string TrailingPunctuation = "?!.,:*_~";
    private const string BoundaryCharacters = "*_~(";
    private const string EmailLocalExtras = ".-_+";

    /// <param name="text">Plain text to scan.</param>
    /// <param name="startsAtBoundary">Whether the position before the text counts as a boundary (start of line, after emphasis...).</param>
    public static List<AutolinkMatch> Scan(string text, bool startsAtBoundary = true)
    {
        var matches = new List<AutolinkMatch>();
        var i = 0;
        while (i < text.Length)
        {
            var atBoundary = i == 0 ? startsAtBoundary : char.IsWhiteSpace(text[i - 1]) || BoundaryCharacters.Contains(text[i - 1]);
            if (atBoundary && (TryWwwOrUrl(text, i) ?? TryEmail(text, i)) is { } match)
            {
                matches.Add(match);
                i = match.Start + match.Length;
                continue;
            }
            i++;
        }
        return matches;
    }

    private static AutolinkMatch? TryWwwOrUrl(string text, int start)
    {
        string? prefix = null;
        if (text.AsSpan(start).StartsWith(WwwPrefix, StringComparison.OrdinalIgnoreCase)) prefix = string.Empty;
        foreach (var scheme in SchemePrefixes)
            if (text.AsSpan(start).StartsWith(scheme, StringComparison.OrdinalIgnoreCase)) prefix = scheme;
        if (prefix is null) return null;

        var domainStart = start + prefix.Length;
        var domainEnd = domainStart;
        while (domainEnd < text.Length && (char.IsAsciiLetterOrDigit(text[domainEnd]) || text[domainEnd] is '-' or '_' or '.')) domainEnd++;
        if (!IsValidDomain(text[domainStart..domainEnd])) return null;

        var end = domainEnd;
        while (end < text.Length && !char.IsWhiteSpace(text[end]) && text[end] != '<') end++;
        end = TrimTrailing(text, start, end);
        if (end <= domainStart) return null;

        var linked = text[start..end];
        return new AutolinkMatch(start, end - start, prefix.Length == 0 ? DefaultScheme + linked : linked);
    }

    /// <summary>At least one period; no underscore in the last two segments.</summary>
    private static bool IsValidDomain(string domain)
    {
        var segments = domain.TrimEnd('.').Split('.');
        if (segments.Length < 2 || segments.Any(s => s.Length == 0)) return false;
        return !segments[^1].Contains('_') && !segments[^2].Contains('_');
    }

    /// <summary>Extended autolink path validation: trailing punctuation, unbalanced ')' and entity references are excluded.</summary>
    private static int TrimTrailing(string text, int start, int end)
    {
        while (end > start)
        {
            var last = text[end - 1];
            if (TrailingPunctuation.Contains(last))
            {
                end--;
            }
            else if (last == ')' && Count(text, start, end, ')') > Count(text, start, end, '('))
            {
                end--;
            }
            else if (last == ';' && EntityStart(text, start, end) is { } entityStart)
            {
                end = entityStart;
            }
            else
            {
                break;
            }
        }
        return end;
    }

    private static int? EntityStart(string text, int start, int end)
    {
        var i = end - 2;
        while (i >= start && char.IsAsciiLetterOrDigit(text[i])) i--;
        return i >= start && i < end - 2 && text[i] == '&' ? i : null;
    }

    private static int Count(string text, int start, int end, char c)
    {
        var n = 0;
        for (var i = start; i < end; i++) if (text[i] == c) n++;
        return n;
    }

    private static AutolinkMatch? TryEmail(string text, int start)
    {
        var at = start;
        while (at < text.Length && (char.IsAsciiLetterOrDigit(text[at]) || EmailLocalExtras.Contains(text[at]))) at++;
        if (at == start || at >= text.Length || text[at] != '@') return null;

        var end = at + 1;
        while (end < text.Length && (char.IsAsciiLetterOrDigit(text[end]) || text[end] is '-' or '_' or '.')) end++;
        if (end > at + 1 && text[end - 1] == '.') end--; // a trailing period is not part of the address
        var domain = text[(at + 1)..end];
        if (!domain.Contains('.') || domain.Length == 0 || domain[^1] is '-' or '_') return null;
        // The address must not continue with characters that are invalid in it (e.g. "@a.b-" or "@a.b_").
        if (end < text.Length && text[end] is '-' or '_') return null;

        var linked = text[start..end];
        return new AutolinkMatch(start, end - start, MailtoScheme + linked);
    }
}

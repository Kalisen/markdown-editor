using MarkdownEditor.Core.Documents;
using MarkdownEditor.Plugins.Abstractions.Preview;

namespace MarkdownEditor.Core.Rendering;

public enum LinkActionKind
{
    Ignore,
    OpenExternal,
    OpenDocument,
}

/// <param name="Target">Absolute URL (external) or file path (document); null when ignored.</param>
public sealed record LinkAction(LinkActionKind Kind, string? Target = null)
{
    public static LinkAction Ignore { get; } = new(LinkActionKind.Ignore);
}

/// <summary>Decides what a link clicked in the preview does.</summary>
public static class PreviewLinkPolicy
{
    private static readonly IReadOnlySet<string> ExternalSchemes =
        new HashSet<string>(StringComparer.OrdinalIgnoreCase) { Uri.UriSchemeHttp, Uri.UriSchemeHttps, Uri.UriSchemeMailto };

    /// <param name="href">The link's href attribute as written in the document (may be relative).</param>
    public static LinkAction Classify(string? href, string? documentFolder)
    {
        if (string.IsNullOrWhiteSpace(href) || href.StartsWith('#')) return LinkAction.Ignore;
        if (!Uri.TryCreate(href, UriKind.Absolute, out var uri))
            return ResolveDocument(href.Split('?', '#')[0], documentFolder);
        if (!ExternalSchemes.Contains(uri.Scheme)) return LinkAction.Ignore;

        if (string.Equals(uri.Host, PreviewHosts.DocumentHost, StringComparison.OrdinalIgnoreCase))
            return ResolveDocument(uri.AbsolutePath, documentFolder);

        return IsInternalHost(uri.Host) ? LinkAction.Ignore : new LinkAction(LinkActionKind.OpenExternal, uri.AbsoluteUri);
    }

    private static bool IsInternalHost(string host) =>
        string.Equals(host, PreviewHosts.AppHost, StringComparison.OrdinalIgnoreCase)
        || host.EndsWith(PreviewHosts.PluginHostSuffix, StringComparison.OrdinalIgnoreCase);

    /// <summary>Markdown files relative to the document folder (parent folders allowed) open in the editor.</summary>
    private static LinkAction ResolveDocument(string relativePath, string? documentFolder)
    {
        if (documentFolder is null) return LinkAction.Ignore;
        var relative = Uri.UnescapeDataString(relativePath).TrimStart('/').Replace('/', Path.DirectorySeparatorChar);
        if (relative.Length == 0 || Path.IsPathRooted(relative)) return LinkAction.Ignore;
        var path = Path.GetFullPath(Path.Combine(documentFolder, relative));
        var isMarkdown = DocumentFileTypes.MarkdownExtensions.Contains(Path.GetExtension(path), StringComparer.OrdinalIgnoreCase);
        return isMarkdown ? new LinkAction(LinkActionKind.OpenDocument, path) : LinkAction.Ignore;
    }
}

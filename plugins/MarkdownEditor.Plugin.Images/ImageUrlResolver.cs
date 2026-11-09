using MarkdownEditor.Plugins.Abstractions.Preview;

namespace MarkdownEditor.Plugin.Images;

/// <summary>Maps document-relative image paths to the preview's document host.</summary>
internal static class ImageUrlResolver
{
    private const char WindowsSeparator = '\\';
    private const char UrlSeparator = '/';
    private const string CurrentDirectoryPrefix = "./";

    public static string Resolve(string url)
    {
        if (url.Length == 0 || url[0] is UrlSeparator or WindowsSeparator or '#') return url;
        // Absolute URLs (and "c:" drive letters, parsed as URI schemes) are left untouched.
        if (Uri.TryCreate(url, UriKind.Absolute, out _)) return url;
        var relative = url.Replace(WindowsSeparator, UrlSeparator);
        if (relative.StartsWith(CurrentDirectoryPrefix, StringComparison.Ordinal))
            relative = relative[CurrentDirectoryPrefix.Length..];
        return PreviewHosts.DocumentOrigin + relative;
    }
}

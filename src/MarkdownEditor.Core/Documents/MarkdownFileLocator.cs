namespace MarkdownEditor.Core.Documents;

/// <summary>
/// Resolves a linked Markdown file. When the exact path does not exist, the first file with the same name
/// under the document's folder tree is used (closest first), like Obsidian's shortest-path wikilinks.
/// </summary>
public sealed class MarkdownFileLocator(Func<string, bool> fileExists, Func<string, string, IEnumerable<string>> findFiles)
{
    public MarkdownFileLocator()
        : this(File.Exists, (root, name) => SafeFind(root, name))
    {
    }

    /// <returns>The path to open, or null when no file is found.</returns>
    public string? Locate(string path, string? documentFolder)
    {
        if (fileExists(path)) return path;
        if (documentFolder is null) return null;

        var name = Path.GetFileName(path);
        return findFiles(documentFolder, name)
            .OrderBy(p => p.Count(c => c == Path.DirectorySeparatorChar))
            .ThenBy(p => p, StringComparer.OrdinalIgnoreCase)
            .FirstOrDefault();
    }

    private static IEnumerable<string> SafeFind(string root, string name)
    {
        var options = new EnumerationOptions { RecurseSubdirectories = true, IgnoreInaccessible = true, MatchCasing = MatchCasing.CaseInsensitive };
        try
        {
            return Directory.EnumerateFiles(root, name, options).ToList();
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            return [];
        }
    }
}

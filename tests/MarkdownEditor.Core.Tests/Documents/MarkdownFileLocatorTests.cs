using MarkdownEditor.Core.Documents;

namespace MarkdownEditor.Core.Tests.Documents;

public class MarkdownFileLocatorTests
{
    private const string Folder = @"C:\vault";

    private static MarkdownFileLocator Locator(params string[] files) =>
        new(p => files.Contains(p, StringComparer.OrdinalIgnoreCase),
            (root, name) => files.Where(f => f.StartsWith(root, StringComparison.OrdinalIgnoreCase)
                                             && string.Equals(Path.GetFileName(f), name, StringComparison.OrdinalIgnoreCase)));

    [Fact]
    public void Existing_path_is_used_as_is() =>
        Assert.Equal(@"C:\vault\Note.md", Locator(@"C:\vault\Note.md", @"C:\vault\a\Note.md").Locate(@"C:\vault\Note.md", Folder));

    [Fact]
    public void Missing_path_falls_back_to_closest_file_with_same_name() =>
        Assert.Equal(@"C:\vault\b\Note.md",
            Locator(@"C:\vault\b\c\Note.md", @"C:\vault\b\Note.md", @"C:\vault\z\Note.md").Locate(@"C:\vault\x\Note.md", Folder));

    [Theory]
    [InlineData(Folder)]
    [InlineData(null)]
    public void Nothing_found_returns_null(string? folder) =>
        Assert.Null(Locator(@"C:\vault\Other.md").Locate(@"C:\vault\Note.md", folder));
}

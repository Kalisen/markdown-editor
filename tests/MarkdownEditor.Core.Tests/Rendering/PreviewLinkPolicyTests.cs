using MarkdownEditor.Core.Rendering;

namespace MarkdownEditor.Core.Tests.Rendering;

public class PreviewLinkPolicyTests
{
    private const string Folder = @"C:\docs";

    [Theory]
    [InlineData("https://example.org/a?b=1", "https://example.org/a?b=1")]
    [InlineData("mailto:me@example.org", "mailto:me@example.org")]
    public void External_links_open_externally(string href, string target) =>
        Assert.Equal(new LinkAction(LinkActionKind.OpenExternal, target), PreviewLinkPolicy.Classify(href, Folder));

    [Theory]
    [InlineData("other.md", @"C:\docs\other.md")]
    [InlineData("sub/My%20Notes.markdown", @"C:\docs\sub\My Notes.markdown")]
    [InlineData("https://doc.mdeditor.local/sub/x.md", @"C:\docs\sub\x.md")]
    [InlineData("../other/x.md#part", @"C:\other\x.md")]
    public void Markdown_links_inside_document_folder_open_in_editor(string href, string path) =>
        Assert.Equal(new LinkAction(LinkActionKind.OpenDocument, path), PreviewLinkPolicy.Classify(href, Folder));

    [Theory]
    [InlineData("#section")]
    [InlineData("")]
    [InlineData(null)]
    [InlineData("image.png")]
    [InlineData("https://app.mdeditor.local/index.html")]
    [InlineData("https://mermaid.plugin.mdeditor.local/x.js")]
    [InlineData("file:///C:/Windows/notepad.exe")]
    [InlineData("javascript:alert(1)")]
    [InlineData(@"C:\Windows\notepad.exe")]
    public void Other_links_are_ignored(string? href) =>
        Assert.Equal(LinkAction.Ignore, PreviewLinkPolicy.Classify(href, Folder));

    [Fact]
    public void Relative_links_are_ignored_for_untitled_documents() =>
        Assert.Equal(LinkAction.Ignore, PreviewLinkPolicy.Classify("other.md", null));
}

using MarkdownEditor.App.Editing;

namespace MarkdownEditor.App.Tests;

public class MarkdownHighlightingTests
{
    [Fact]
    public void Syntax_definition_is_valid() =>
        Assert.Equal("Markdown", MarkdownHighlighting.Load().Name);
}

using MarkdownEditor.Core.Rendering;

namespace MarkdownEditor.Core.Tests.Rendering;

public class SourceLineAnnotatorTests
{
    private static string Annotated(string markdown) =>
        new MarkdownRenderer().RenderDocument(markdown, annotateSourceLines: true).Html;

    [Fact]
    public void Blocks_carry_their_first_and_last_source_lines()
    {
        var html = Annotated("# Title\n\nfirst line\nsecond line\n");

        Assert.Contains("<h1 data-line=\"0\" data-line-end=\"0\">", html);
        Assert.Contains("<p data-line=\"2\" data-line-end=\"3\">", html);
    }

    [Fact]
    public void Nested_blocks_are_annotated()
    {
        var html = Annotated("- a\n- b\n");

        Assert.Contains("<ul data-line=\"0\" data-line-end=\"1\">", html);
        Assert.Contains("<li data-line=\"1\" data-line-end=\"1\">", html);
    }

    [Fact]
    public void Crlf_line_breaks_are_counted_once()
    {
        var html = Annotated("a\r\nb\r\n\r\n```\r\ncode\r\n```\r\n");

        Assert.Contains("data-line=\"3\" data-line-end=\"5\"", html);
    }

    [Fact]
    public void Plain_rendering_is_not_annotated() =>
        Assert.Equal("<p>a</p>\n", new MarkdownRenderer().Render("a"));
}

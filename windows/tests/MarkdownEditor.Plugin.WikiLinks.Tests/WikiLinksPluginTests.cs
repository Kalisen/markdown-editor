using Markdig;

namespace MarkdownEditor.Plugin.WikiLinks.Tests;

public class WikiLinksPluginTests
{
    private static string Render(string markdown)
    {
        var builder = new MarkdownPipelineBuilder();
        new WikiLinksPlugin().ConfigurePipeline(builder);
        return Markdown.ToHtml(markdown, builder.Build());
    }

    [Theory]
    [InlineData("[[Note]]", "<a href=\"Note.md\" class=\"wikilink\">Note</a>")]
    [InlineData("[[My Note]]", "<a href=\"My%20Note.md\" class=\"wikilink\">My Note</a>")]
    [InlineData("[[folder/Note|the note]]", "<a href=\"folder/Note.md\" class=\"wikilink\">the note</a>")]
    [InlineData("[[Note#Setup]]", "<a href=\"Note.md\" class=\"wikilink\">Note &gt; Setup</a>")]
    [InlineData("[[Note#Setup|alias]]", "<a href=\"Note.md\" class=\"wikilink\">alias</a>")]
    [InlineData("[[diagram.png]]", "<a href=\"diagram.png\" class=\"wikilink\">diagram.png</a>")]
    public void Wikilinks_render_as_links_to_markdown_files(string markdown, string link) =>
        Assert.Equal($"<p>See {link} now</p>\n", Render($"See {markdown} now"));

    [Theory]
    [InlineData("[[]]")]
    [InlineData("[[|alias]]")]
    [InlineData("[[unclosed")]
    [InlineData("`[[Note]]`")]
    public void Invalid_or_code_wikilinks_are_not_links(string markdown) =>
        Assert.DoesNotContain("wikilink", Render(markdown));

    [Fact]
    public void Standard_links_still_work() =>
        Assert.Equal("<p><a href=\"a.md\">x</a> and <a href=\"B.md\" class=\"wikilink\">B</a></p>\n", Render("[x](a.md) and [[B]]"));
}

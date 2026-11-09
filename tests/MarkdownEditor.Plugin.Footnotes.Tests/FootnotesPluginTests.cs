using Markdig;

namespace MarkdownEditor.Plugin.Footnotes.Tests;

public class FootnotesPluginTests
{
    private static string Render(string markdown)
    {
        var builder = new MarkdownPipelineBuilder();
        new FootnotesPlugin().ConfigurePipeline(builder);
        return Markdown.ToHtml(markdown, builder.Build());
    }

    [Fact]
    public void Reference_links_to_numbered_definition_with_back_link()
    {
        var html = Render("Claim[^note] and more[^2].\n\n[^note]: First source.\n[^2]: Second.\n");

        Assert.Contains("<a id=\"fnref:1\" href=\"#fn:1\" class=\"footnote-ref\"><sup>1</sup></a>", html);
        Assert.Contains("<a id=\"fnref:2\" href=\"#fn:2\" class=\"footnote-ref\"><sup>2</sup></a>", html);
        Assert.Contains("<div class=\"footnotes\">", html);
        Assert.Contains("<li id=\"fn:1\">", html);
        Assert.Contains("First source.<a href=\"#fnref:1\" class=\"footnote-back-ref\">", html);
    }

    [Fact]
    public void Multi_paragraph_definition()
    {
        var html = Render("Text[^a].\n\n[^a]: Para one.\n\n    Para two.\n");
        Assert.Contains("<p>Para one.</p>", html);
        Assert.Contains("<p>Para two.", html);
    }

    [Fact]
    public void Undefined_reference_stays_text() =>
        Assert.Equal("<p>Text[^missing].</p>\n", Render("Text[^missing]."));

    [Fact]
    public void Declared_stylesheet_exists() =>
        Assert.True(File.Exists(Path.Combine(AppContext.BaseDirectory, FootnotesPlugin.StylesheetPath)));
}

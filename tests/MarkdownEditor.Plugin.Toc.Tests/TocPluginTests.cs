using Markdig;

namespace MarkdownEditor.Plugin.Toc.Tests;

public class TocPluginTests
{
    private static string Render(string markdown)
    {
        var builder = new MarkdownPipelineBuilder();
        new TocPlugin().ConfigurePipeline(builder);
        return Markdown.ToHtml(markdown, builder.Build());
    }

    [Theory]
    [InlineData("[TOC]")]
    [InlineData("[toc]")]
    [InlineData("[[_TOC_]]")]
    public void Marker_renders_nested_list_of_heading_links(string marker)
    {
        var html = Render($"# Title\n\n{marker}\n\n## Setup\n\n### Install `tool`\n\n## Usage\n");

        Assert.Contains("<nav class=\"table-of-contents\">\n<ul>\n<li><a href=\"#title\">Title</a><ul>\n" +
                        "<li><a href=\"#setup\">Setup</a><ul>\n<li><a href=\"#install-tool\">Install tool</a></li>\n</ul>\n</li>\n" +
                        "<li><a href=\"#usage\">Usage</a></li>\n</ul>\n</li>\n</ul>\n</nav>", html);
        Assert.Contains("<h3 id=\"install-tool\">", html);
    }

    [Fact]
    public void Headings_after_the_marker_and_level_jumps_are_included()
    {
        var html = Render("[TOC]\n\n### Deep first\n\n# Top\n");
        Assert.Contains("<li><a href=\"#deep-first\">Deep first</a></li>", html);
        Assert.Contains("<li><a href=\"#top\">Top</a></li>", html);
        Assert.Equal(html.Split("<ul>").Length - 1, html.Split("</ul>").Length - 1);
    }

    [Theory]
    [InlineData("See [TOC] here\n")]
    [InlineData("text\n[TOC]\n")]
    [InlineData("    [TOC]\n")]
    [InlineData("`[TOC]`\n")]
    public void Marker_inside_text_or_code_is_not_a_toc(string markdown) =>
        Assert.DoesNotContain("table-of-contents", Render(markdown));

    [Fact]
    public void Heading_text_is_html_escaped() =>
        Assert.Contains(">a &lt; b &amp; c</a>", Render("[TOC]\n\n# a < b & c\n"));

    [Fact]
    public void Empty_document_toc_is_empty_nav() =>
        Assert.Equal("<nav class=\"table-of-contents\">\n</nav>\n", Render("[TOC]\n"));
}

using Markdig;
using MarkdownEditor.Tests.Shared;

namespace MarkdownEditor.Plugin.Tables.Tests;

public class TablesPluginTests
{
    private static string Render(string markdown)
    {
        var builder = new MarkdownPipelineBuilder();
        new TablesPlugin().ConfigurePipeline(builder);
        return Markdown.ToHtml(markdown, builder.Build());
    }

    [Fact]
    public void Pipe_table_renders_with_header_body_and_alignment()
    {
        var html = Render("| Turn | Name | Mid |\n| ---: | :--- | :---: |\n| 0 | a | x |\n| 1 | b | y |\n");

        Assert.Contains("<thead>", html);
        Assert.Contains("<tbody>", html);
        Assert.Contains("<th align=\"right\">Turn</th>", html);
        Assert.Contains("<td align=\"left\">b</td>", html);
        Assert.Contains("<td align=\"center\">y</td>", html);
        Assert.Equal(3, html.Split("<tr>").Length - 1);
    }

    [Fact]
    public void Table_after_paragraph_and_heading_renders()
    {
        var html = Render("### Title\n\nSome text.\n\n| a | b |\n| --- | --- |\n| 1 | 2 |\n");
        Assert.Contains("<h3>Title</h3>", html);
        Assert.Contains("<table>", html);
    }

    [Theory]
    [InlineData("a | b\n")]
    [InlineData("| a | b |\n")]
    public void Pipes_without_delimiter_row_are_not_a_table(string markdown) =>
        Assert.DoesNotContain("<table>", Render(markdown));

    [Fact]
    public void Earlier_paragraph_lines_stay_a_paragraph() =>
        Assert.StartsWith("<p>intro</p>\n<table>", Render("intro\n| a | b |\n| - | - |\n| 1 | 2 |\n"));

    [Theory]
    [InlineData("> | a | b |\n> | - | - |\n> | 1 | 2 |\n", "<blockquote>\n<table>")]
    [InlineData("- item\n\n  | a | b |\n  | - | - |\n  | 1 | 2 |\n", "<table>")]
    public void Tables_nest_in_containers(string markdown, string expected) =>
        Assert.Contains(expected, Render(markdown));

    [Fact]
    public void Heading_ends_the_table() =>
        Assert.EndsWith("</table>\n<h2>next</h2>\n", Render("| a |\n| - |\n| 1 |\n## next\n"));

    [Fact]
    public void Indented_delimiter_row_is_not_a_table() =>
        Assert.DoesNotContain("<table>", Render("| a | b |\n    | - | - |\n"));

    public static TheoryData<GfmSpec.Example> SpecExamples() => GfmSpec.For("table");

    [Theory]
    [MemberData(nameof(SpecExamples))]
    public void Gfm_spec_table_examples(GfmSpec.Example example) =>
        Assert.Equal(GfmSpec.Normalize(example.Html), GfmSpec.Normalize(Render(example.Markdown)));

    [Fact]
    public void Declared_stylesheet_exists() =>
        Assert.True(File.Exists(Path.Combine(AppContext.BaseDirectory, TablesPlugin.StylesheetPath)));
}

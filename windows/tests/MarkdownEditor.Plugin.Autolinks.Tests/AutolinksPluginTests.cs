using Markdig;
using Markdig.Syntax;
using MarkdownEditor.Tests.Shared;

namespace MarkdownEditor.Plugin.Autolinks.Tests;

public class AutolinksPluginTests
{
    private static string Render(string markdown)
    {
        var builder = new MarkdownPipelineBuilder();
        new AutolinksPlugin().ConfigurePipeline(builder);
        return Markdown.ToHtml(markdown, builder.Build());
    }

    public static TheoryData<GfmSpec.Example> SpecExamples() => GfmSpec.For("autolink");

    [Theory]
    [MemberData(nameof(SpecExamples))]
    public void Gfm_spec_autolink_examples(GfmSpec.Example example) =>
        Assert.Equal(GfmSpec.Normalize(example.Html), GfmSpec.Normalize(Render(example.Markdown)));

    [Theory]
    [InlineData("[www.example.com](http://x.org)", "<p><a href=\"http://x.org\">www.example.com</a></p>\n")]
    [InlineData("`www.example.com`", "<p><code>www.example.com</code></p>\n")]
    [InlineData("xwww.example.com", "<p>xwww.example.com</p>\n")]
    [InlineData("www.a_b.c_d", "<p>www.a_b.c_d</p>\n")]
    public void Existing_links_code_and_non_boundaries_are_left_alone(string markdown, string html) =>
        Assert.Equal(html, Render(markdown));

    [Fact]
    public void Autolink_inside_emphasis_and_with_underscores_in_path()
    {
        Assert.Equal("<p><em><a href=\"http://www.example.com\">www.example.com</a></em></p>\n", Render("*www.example.com*"));
        Assert.Contains("href=\"http://www.example.com/a_b_c\"", Render("see www.example.com/a_b_c now"));
    }

    [Theory]
    [InlineData("*a* www.example.com")]
    [InlineData("*a* www.example.com *b*")]
    [InlineData("www.example.com *a*")]
    public void Rewritten_paragraph_keeps_a_consistent_inline_tree(string markdown)
    {
        var builder = new MarkdownPipelineBuilder();
        new AutolinksPlugin().ConfigurePipeline(builder);
        var document = Markdown.Parse(markdown, builder.Build());

        // Tree walks (used by later processing and usage probes) must see every node, not only the new ones.
        var emphasis = document.Descendants<Markdig.Syntax.Inlines.EmphasisInline>().Count();
        Assert.Equal(markdown.Split('*').Length / 2, emphasis);
        Assert.Single(document.Descendants<Markdig.Syntax.Inlines.LinkInline>());
    }
}

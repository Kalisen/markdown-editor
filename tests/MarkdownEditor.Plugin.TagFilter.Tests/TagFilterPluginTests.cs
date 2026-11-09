using Markdig;
using MarkdownEditor.Tests.Shared;

namespace MarkdownEditor.Plugin.TagFilter.Tests;

public class TagFilterPluginTests
{
    private static string Render(string markdown)
    {
        var builder = new MarkdownPipelineBuilder();
        new TagFilterPlugin().ConfigurePipeline(builder);
        return Markdown.ToHtml(markdown, builder.Build());
    }

    public static TheoryData<GfmSpec.Example> SpecExamples() => GfmSpec.For("tagfilter");

    [Theory]
    [MemberData(nameof(SpecExamples))]
    public void Gfm_spec_tagfilter_examples(GfmSpec.Example example) =>
        Assert.Equal(GfmSpec.Normalize(example.Html), GfmSpec.Normalize(Render(example.Markdown)));

    [Theory]
    [InlineData("<script>x</script>\n", "&lt;script>x&lt;/script>\n")]
    [InlineData("a <IFRAME src=x> b\n", "<p>a &lt;IFRAME src=x> b</p>\n")]
    [InlineData("<div><style>p{}</style></div>\n", "<div>&lt;style>p{}&lt;/style></div>\n")]
    public void Disallowed_tags_are_escaped_in_html_blocks_and_inlines(string markdown, string html) =>
        Assert.Equal(html, Render(markdown));

    [Theory]
    [InlineData("<div class=\"x\">ok</div>\n", "<div class=\"x\">ok</div>\n")]
    [InlineData("<titles>\n", "<titles>\n")]
    [InlineData("`<script>`\n", "<p><code>&lt;script&gt;</code></p>\n")]
    public void Other_tags_and_code_are_unchanged(string markdown, string html) =>
        Assert.Equal(html, Render(markdown));
}

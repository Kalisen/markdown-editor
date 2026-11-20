using Markdig;
using MarkdownEditor.Tests.Shared;

namespace MarkdownEditor.Plugin.Strikethrough.Tests;

public class StrikethroughPluginTests
{
    private static string Render(string markdown)
    {
        var builder = new MarkdownPipelineBuilder();
        new StrikethroughPlugin().ConfigurePipeline(builder);
        return Markdown.ToHtml(markdown, builder.Build());
    }

    public static TheoryData<GfmSpec.Example> SpecExamples() => GfmSpec.For("strikethrough");

    [Theory]
    [MemberData(nameof(SpecExamples))]
    public void Gfm_spec_strikethrough_examples(GfmSpec.Example example) =>
        Assert.Equal(GfmSpec.Normalize(example.Html), GfmSpec.Normalize(Render(example.Markdown)));

    [Theory]
    [InlineData("~one~", "<p><del>one</del></p>\n")]
    [InlineData("a ~~b **c**~~ d", "<p>a <del>b <strong>c</strong></del> d</p>\n")]
    public void Single_tilde_and_nested_emphasis(string markdown, string html) =>
        Assert.Equal(html, Render(markdown));

    [Theory]
    [InlineData("H~2~O")]
    [InlineData("x^2^")]
    [InlineData("==mark==")]
    [InlineData("++ins++")]
    public void Other_emphasis_extras_are_not_enabled(string markdown) =>
        Assert.DoesNotContain("<", Render(markdown).Replace("<p>", "").Replace("</p>", ""));
}

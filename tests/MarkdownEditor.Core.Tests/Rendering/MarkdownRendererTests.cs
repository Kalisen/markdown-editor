using Markdig;
using MarkdownEditor.Core.Rendering;
using MarkdownEditor.Core.Tests.Fakes;

namespace MarkdownEditor.Core.Tests.Rendering;

public class MarkdownRendererTests
{
    [Fact]
    public void Core_pipeline_does_not_enable_non_commonmark_syntax() =>
        Assert.Equal("<p>~~x~~</p>\n", new MarkdownRenderer().Render("~~x~~"));

    [Fact]
    public void Plugin_extensions_are_applied() =>
        Assert.Equal("<p><del>x</del></p>\n",
            new MarkdownRenderer([new FakePlugin("strike") { Configure = b => b.UseEmphasisExtras() }]).Render("~~x~~"));

    [Fact]
    public void Failing_plugin_is_excluded_and_reported()
    {
        var bad = new FakePlugin("bad") { Configure = _ => throw new InvalidOperationException("boom") };
        var good = new FakePlugin("good");

        var renderer = new MarkdownRenderer([bad, good]);

        Assert.Equal([good], renderer.ActivePlugins);
        var failure = Assert.Single(renderer.Failures);
        Assert.Equal(("bad", "boom"), (failure.Source, failure.Reason));
        Assert.Equal("<p>ok</p>\n", renderer.Render("ok"));
    }
}

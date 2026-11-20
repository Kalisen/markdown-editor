using Markdig;
using Markdig.Syntax;
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

    private sealed class ProbingPlugin(string id, Func<Markdig.Syntax.MarkdownDocument, bool> probe)
        : MarkdownEditor.Plugins.Abstractions.IMarkdownPlugin, MarkdownEditor.Plugins.Abstractions.IDocumentFeatureProbe
    {
        public string Id => id;
        public string Name => id;
        public Version Version => new(1, 0);
        public IReadOnlyList<MarkdownEditor.Plugins.Abstractions.Preview.PreviewAsset> PreviewAssets => [];
        public void ConfigurePipeline(MarkdownPipelineBuilder builder) => builder.UseEmphasisExtras();
        public bool IsUsedBy(Markdig.Syntax.MarkdownDocument document) => probe(document);
    }

    [Fact]
    public void Render_document_reports_plugins_whose_probe_matches()
    {
        var usesStrike = new ProbingPlugin("strike", d => d.Descendants<Markdig.Syntax.Inlines.EmphasisInline>().Any(e => e.DelimiterChar == '~'));
        var never = new ProbingPlugin("never", _ => false);
        var throws = new ProbingPlugin("throws", _ => throw new InvalidOperationException());
        var noProbe = new FakePlugin("no-probe");
        var renderer = new MarkdownRenderer([usesStrike, never, throws, noProbe]);

        var used = renderer.RenderDocument("~~x~~");
        var unused = renderer.RenderDocument("plain");

        Assert.Equal("<p><del>x</del></p>\n", used.Html);
        Assert.Equal([usesStrike], used.UsedPlugins);
        Assert.Empty(unused.UsedPlugins);
    }

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

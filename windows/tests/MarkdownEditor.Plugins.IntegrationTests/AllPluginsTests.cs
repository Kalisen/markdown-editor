using MarkdownEditor.Core.Rendering;
using MarkdownEditor.Plugins.Abstractions;

namespace MarkdownEditor.Plugins.IntegrationTests;

/// <summary>All bundled plugins configured together, as in the app.</summary>
public class AllPluginsTests
{
    private static readonly IReadOnlyList<IMarkdownPlugin> Plugins =
    [
        new Plugin.Alerts.AlertsPlugin(), new Plugin.Autolinks.AutolinksPlugin(), new Plugin.Emoji.EmojiPlugin(),
        new Plugin.Footnotes.FootnotesPlugin(), new Plugin.FrontMatter.FrontMatterPlugin(), new Plugin.Graphviz.GraphvizPlugin(),
        new Plugin.HeadingAnchors.HeadingAnchorsPlugin(), new Plugin.Images.ImagesPlugin(), new Plugin.Math.MathPlugin(),
        new Plugin.Mermaid.MermaidPlugin(), new Plugin.Strikethrough.StrikethroughPlugin(),
        new Plugin.SyntaxHighlighting.SyntaxHighlightingPlugin(), new Plugin.Tables.TablesPlugin(),
        new Plugin.TagFilter.TagFilterPlugin(), new Plugin.TaskLists.TaskListsPlugin(), new Plugin.Toc.TocPlugin(),
        new Plugin.WikiLinks.WikiLinksPlugin(),
    ];

    private static readonly MarkdownRenderer Renderer = new(Plugins);

    [Fact]
    public void All_bundled_plugins_load_configure_and_report_usage()
    {
        Assert.Equal(17, Plugins.Count);
        Assert.Empty(Renderer.Failures);
        Assert.All(Plugins, p => Assert.IsAssignableFrom<IDocumentFeatureProbe>(p));
    }

    [Theory]
    [InlineData("images", "![x](a.png)")]
    [InlineData("mermaid", "```mermaid\ngraph TD\nA-->B\n```")]
    [InlineData("tables", "| a | b |\n| - | - |\n| 1 | 2 |")]
    [InlineData("task-lists", "- [ ] todo")]
    [InlineData("strikethrough", "~~gone~~")]
    [InlineData("autolinks", "see www.example.com")]
    [InlineData("tag-filter", "<script>x</script>")]
    [InlineData("footnotes", "x[^1]\n\n[^1]: note")]
    [InlineData("alerts", "> [!NOTE]\n> hi")]
    [InlineData("heading-anchors", "# Title")]
    [InlineData("emoji", "go :rocket:")]
    [InlineData("syntax-highlighting", "```csharp\nvar x = 1;\n```")]
    [InlineData("math", "$x^2$")]
    [InlineData("toc", "[TOC]")]
    [InlineData("front-matter", "---\ntitle: x\n---\nbody")]
    [InlineData("wikilinks", "[[Note]]")]
    [InlineData("graphviz", "```dot\ndigraph { a -> b }\n```")]
    public void Each_plugin_is_reported_only_when_its_syntax_is_used(string id, string markdown)
    {
        var used = Renderer.RenderDocument(markdown).UsedPlugins.Select(p => p.Id).ToList();

        Assert.Contains(id, used);
        // Heading anchors also apply wherever there is a heading; the TOC adds heading ids itself.
        Assert.All(used, u => Assert.True(u == id || (id == "toc" && u == "heading-anchors") || id == "heading-anchors", $"{u} reported for {id}"));
    }

    [Theory]
    [InlineData("Just a paragraph with *emphasis*, `code` and a [link](https://x.org).")]
    [InlineData("```\nplain code\n```")]
    [InlineData("> quote\n\n- item")]
    public void Plain_commonmark_uses_no_extension(string markdown) =>
        Assert.Empty(Renderer.RenderDocument(markdown).UsedPlugins);

    [Fact]
    public void Plugins_coexist_in_one_document()
    {
        var result = Renderer.RenderDocument(
            "---\ntitle: All\n---\n# Doc :rocket:\n\n[TOC]\n\n- [x] ~~done~~ www.x.org\n\n| a |\n| - |\n| $y$ |\n\n" +
            "> [!TIP]\n> See [[Other]][^n].\n\n```mermaid\ngraph TD\nA-->B\n```\n\n```python\nprint(1)\n```\n\n[^n]: note\n");

        Assert.Equal(["alerts", "autolinks", "emoji", "footnotes", "front-matter", "heading-anchors", "math", "mermaid", "strikethrough", "syntax-highlighting", "tables", "task-lists", "toc", "wikilinks"],
            result.UsedPlugins.Select(p => p.Id).Order());
        Assert.Contains("<table class=\"front-matter\">", result.Html);
        Assert.Contains("<nav class=\"table-of-contents\">", result.Html);
        Assert.Contains("<td><span class=\"math\">", result.Html);
        Assert.Contains("class=\"wikilink\"", result.Html);
    }
}

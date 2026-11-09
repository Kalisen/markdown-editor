using Markdig;

namespace MarkdownEditor.Plugin.FrontMatter.Tests;

public class FrontMatterPluginTests
{
    private static string Render(string markdown)
    {
        var builder = new MarkdownPipelineBuilder();
        new FrontMatterPlugin().ConfigurePipeline(builder);
        return Markdown.ToHtml(markdown, builder.Build());
    }

    [Fact]
    public void Front_matter_renders_as_table_and_body_follows()
    {
        var html = Render("---\ntitle: Hello <World>\ntags: [a, \"b c\"]\ncreated: 2026-11-09\n---\n\n# Body\n");

        Assert.StartsWith("<table class=\"front-matter\">", html);
        Assert.Contains("<th>title</th>", html);
        Assert.Contains("<td>Hello &lt;World&gt;</td>", html);
        Assert.Contains("<td><ul><li>a</li><li>b c</li></ul></td>", html);
        Assert.Contains("<td>2026-11-09</td>", html);
        Assert.Contains("<h1>Body</h1>", html);
        Assert.DoesNotContain("---", html);
    }

    [Fact]
    public void Front_matter_must_be_at_the_start() =>
        Assert.DoesNotContain("front-matter", Render("Intro\n\n---\ntitle: x\n---\n"));

    [Fact]
    public void Front_matter_without_keys_renders_nothing() =>
        Assert.Equal("<p>Body</p>\n", Render("---\n# only a comment\n---\nBody\n"));

    [Fact]
    public void Parses_scalars_quotes_comments_block_lists_and_nested_mappings()
    {
        var entries = FrontMatterYaml.Parse(
            "title: 'Quoted # not comment'\n" +
            "status: draft # a comment\n" +
            "tags:\n  - one\n  - two\n" +
            "author:\n  name: Me\n  email: me@example.org\n" +
            "empty:\n" +
            "# full line comment\n");

        Assert.Equal(
            [
                new FrontMatterEntry("title", ["Quoted # not comment"]),
                new FrontMatterEntry("status", ["draft"]),
                new FrontMatterEntry("tags", ["one", "two"]),
                new FrontMatterEntry("author", ["name: Me\nemail: me@example.org"], IsRaw: true),
                new FrontMatterEntry("empty", []),
            ],
            entries,
            (a, b) => a.Key == b.Key && a.IsRaw == b.IsRaw && a.Values.SequenceEqual(b.Values));
    }
}

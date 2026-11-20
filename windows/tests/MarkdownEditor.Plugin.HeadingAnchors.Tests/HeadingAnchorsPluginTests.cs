using Markdig;

namespace MarkdownEditor.Plugin.HeadingAnchors.Tests;

public class HeadingAnchorsPluginTests
{
    private static string Render(string markdown)
    {
        var builder = new MarkdownPipelineBuilder();
        new HeadingAnchorsPlugin().ConfigurePipeline(builder);
        return Markdown.ToHtml(markdown, builder.Build());
    }

    // Expected ids are the ones github.com generates for the same headings.
    [Theory]
    [InlineData("# Hello World", "hello-world")]
    [InlineData("## Agent session (conversation cache)", "agent-session-conversation-cache")]
    [InlineData("### What's new in v1.2?", "whats-new-in-v12")]
    [InlineData("## snake_case and kebab-case", "snake_case-and-kebab-case")]
    [InlineData("## `code` heading", "code-heading")]
    [InlineData("## Émoji & Ünïcode", "émoji--ünïcode")]
    public void Ids_match_github(string markdown, string id) =>
        Assert.Contains($"id=\"{id}\"", Render(markdown));

    [Fact]
    public void Duplicate_headings_are_suffixed()
    {
        var html = Render("## Setup\n\n## Setup\n\n## Setup\n");
        Assert.Contains("id=\"setup\"", html);
        Assert.Contains("id=\"setup-1\"", html);
        Assert.Contains("id=\"setup-2\"", html);
    }

    [Fact]
    public void Declared_assets_exist() =>
        Assert.All(new HeadingAnchorsPlugin().PreviewAssets,
            a => Assert.True(File.Exists(Path.Combine(AppContext.BaseDirectory, a.RelativePath)), a.RelativePath));
}

using Markdig;
using MarkdownEditor.Plugin.Images;

namespace MarkdownEditor.Plugin.Images.Tests;

public class ImagesPluginTests
{
    private static string Render(string markdown)
    {
        var builder = new MarkdownPipelineBuilder();
        new ImagesPlugin().ConfigurePipeline(builder);
        return Markdown.ToHtml(markdown, builder.Build());
    }

    [Theory]
    [InlineData("img/a.png", "https://doc.mdeditor.local/img/a.png")]
    [InlineData("./a.png", "https://doc.mdeditor.local/a.png")]
    [InlineData(@"img\a.png", "https://doc.mdeditor.local/img/a.png")]
    [InlineData("https://x.org/a.png", "https://x.org/a.png")]
    [InlineData("data:image/png;base64,AA", "data:image/png;base64,AA")]
    [InlineData("/root.png", "/root.png")]
    [InlineData(@"C:\pics\a.png", @"C:\pics\a.png")]
    public void Resolves_relative_urls_against_document_host(string url, string expected) =>
        Assert.Equal(expected, ImageUrlResolver.Resolve(url));

    [Fact]
    public void Renders_relative_image_lazily_from_document_host() =>
        Assert.Equal("<p><img src=\"https://doc.mdeditor.local/a.png\" loading=\"lazy\" alt=\"x\" title=\"t\" /></p>\n",
            Render("![x](a.png \"t\")"));

    [Theory]
    [InlineData("=200x100", "width=\"200\" height=\"100\"")]
    [InlineData("=200x", "width=\"200\"")]
    [InlineData("=x50", "height=\"50\"")]
    public void Size_hint_title_becomes_dimensions(string hint, string attributes) =>
        Assert.Equal($"<p><img src=\"https://doc.mdeditor.local/a.png\" {attributes} loading=\"lazy\" alt=\"x\" /></p>\n",
            Render($"![x](a.png \"{hint}\")"));

    [Theory]
    [InlineData(null)]
    [InlineData("x")]
    [InlineData("=x")]
    [InlineData("=axb")]
    [InlineData("=99999999999x10")]
    public void Non_hint_titles_are_not_size_hints(string? title) =>
        Assert.False(ImageSizeHint.TryParse(title, out _));

    [Fact]
    public void Links_are_not_rewritten() =>
        Assert.Equal("<p><a href=\"a.md\">x</a></p>\n", Render("[x](a.md)"));

    [Fact]
    public void Declares_stylesheet_that_exists_in_plugin_output()
    {
        var asset = Assert.Single(new ImagesPlugin().PreviewAssets);
        Assert.True(File.Exists(Path.Combine(AppContext.BaseDirectory, asset.RelativePath)));
    }
}

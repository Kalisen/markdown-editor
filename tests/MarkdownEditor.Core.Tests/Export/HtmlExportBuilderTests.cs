using MarkdownEditor.Core.Export;
using MarkdownEditor.Core.Rendering;

namespace MarkdownEditor.Core.Tests.Export;

public class HtmlExportBuilderTests
{
    [Fact]
    public void Builds_standalone_page_with_inlined_resolvable_styles_and_no_scripts()
    {
        var snapshot = new PreviewSnapshot("<h1>Hi</h1><svg></svg>", ["https://a/x.css", "https://a/missing.css", "https://a/x.css"]);

        var html = HtmlExportBuilder.Build("My <Doc>", snapshot, PreviewTheme.Light,
            url => url.EndsWith("x.css") ? "body{color:red}</style>" : null);

        Assert.Contains("<title>My &lt;Doc&gt;</title>", html);
        Assert.Contains("<html data-theme=\"light\">", html);
        Assert.Contains("<main id=\"content\" class=\"markdown-body\">\n<h1>Hi</h1><svg></svg>\n</main>", html);
        Assert.Single(html.Split("body{color:red}").Skip(1));
        Assert.Contains("<\\/style>", html);
        Assert.DoesNotContain("missing.css */", html);
        Assert.DoesNotContain("<script", html);
    }

    [Theory]
    [InlineData("https://app.mdeditor.local/preview.css", @"C:\app\preview.css")]
    [InlineData("https://math.plugin.mdeditor.local/assets/vendor/katex.min.css", @"C:\plugins\math\assets\vendor\katex.min.css")]
    [InlineData("https://math.plugin.mdeditor.local/a%20b.css", @"C:\plugins\math\a b.css")]
    public void Resolves_preview_urls_to_files(string url, string path) =>
        Assert.Equal(path, Resolver().Resolve(url));

    [Theory]
    [InlineData("https://example.org/x.css")]
    [InlineData("https://unknown.plugin.mdeditor.local/x.css")]
    [InlineData("https://doc.mdeditor.local/x.css")]
    [InlineData("https://math.plugin.mdeditor.local/..%5C..%5Csecret.css")]
    [InlineData("not a url")]
    public void Other_urls_are_not_resolved(string url) =>
        Assert.Null(Resolver().Resolve(url));

    private static PreviewAssetResolver Resolver() =>
        new(@"C:\app", new Dictionary<string, string> { ["math"] = @"C:\plugins\math" });
}

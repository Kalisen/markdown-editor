using Markdig;

namespace MarkdownEditor.Plugin.Math.Tests;

public class MathPluginTests
{
    private static string Render(string markdown)
    {
        var builder = new MarkdownPipelineBuilder();
        new MathPlugin().ConfigurePipeline(builder);
        return Markdown.ToHtml(markdown, builder.Build());
    }

    [Theory]
    [InlineData("$a<b$", "<span class=\"math\">\\(a&lt;b\\)</span>")]
    [InlineData("$`x^2`$", "<span class=\"math\">\\(x^2\\)</span>")]
    [InlineData("$\\sqrt{3x-1}+(1+x)^2$", "<span class=\"math\">\\(\\sqrt{3x-1}+(1+x)^2\\)</span>")]
    public void Inline_math_is_marked_for_typesetting(string markdown, string html) =>
        Assert.Contains(html, Render(markdown));

    [Fact]
    public void Block_math_is_marked_for_display_typesetting() =>
        Assert.Equal("<div class=\"math\">\n\\[\n\\sum_i x_i\n\\]</div>\n", Render("$$\n\\sum_i x_i\n$$\n"));

    [Fact]
    public void Math_fence_stays_a_language_math_code_block() =>
        Assert.Equal("<pre><code class=\"language-math\">E=mc^2\n</code></pre>\n", Render("```math\nE=mc^2\n```\n"));

    [Theory]
    [InlineData("It costs $5 and $6.", "<p>It costs $5 and $6.</p>\n")]
    [InlineData("`$x$`", "<p><code>$x$</code></p>\n")]
    public void Currency_and_code_are_not_math(string markdown, string html) =>
        Assert.Equal(html, Render(markdown));

    [Fact]
    public void Declared_assets_and_fonts_exist()
    {
        Assert.All(new MathPlugin().PreviewAssets,
            a => Assert.True(File.Exists(Path.Combine(AppContext.BaseDirectory, a.RelativePath)), a.RelativePath));
        Assert.NotEmpty(Directory.GetFiles(Path.Combine(AppContext.BaseDirectory, MathPlugin.VendorFolder, "fonts"), "*.woff2"));
    }

    [Fact]
    public void Bundled_katex_is_the_targeted_version_and_does_not_need_eval()
    {
        var script = File.ReadAllText(Path.Combine(AppContext.BaseDirectory, MathPlugin.KatexScriptPath));
        Assert.Contains($"\"{MathPlugin.KatexVersion}\"", script);
        Assert.DoesNotContain("new Function", script); // the preview CSP forbids eval
    }
}

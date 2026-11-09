using MarkdownEditor.Core.Rendering;
using MarkdownEditor.Core.Tests.Fakes;
using MarkdownEditor.Plugins.Abstractions.Preview;

namespace MarkdownEditor.Core.Tests.Rendering;

public class PreviewPageBuilderTests
{
    private static readonly PreviewPage Page = PreviewPageBuilder.Build(PreviewTheme.Dark,
        [new FakePlugin("demo", PreviewAsset.Stylesheet("a.css"), PreviewAsset.Script("/js/b.js"))]);

    private static string Html => Page.Files[PreviewPageBuilder.PageFileName];

    [Fact]
    public void Page_includes_theme_host_script_and_plugin_assets_served_from_plugin_host()
    {
        Assert.Contains("<html data-theme=\"dark\">", Html);
        Assert.Contains("<link rel=\"stylesheet\" href=\"https://demo.plugin.mdeditor.local/a.css\">", Html);
        Assert.Contains("<script src=\"https://demo.plugin.mdeditor.local/js/b.js\"></script>", Html);
        Assert.True(Html.IndexOf("src=\"preview.js\"", StringComparison.Ordinal)
                    < Html.IndexOf("js/b.js", StringComparison.Ordinal), "host API must load before plugin scripts");
        Assert.Contains("window.mdeditor = {", Page.Files[PreviewPageBuilder.ScriptFileName]);
        Assert.Contains(".markdown-body", Page.Files[PreviewPageBuilder.StyleFileName]);
    }

    [Fact]
    public void Page_has_no_inline_script_and_declares_csp()
    {
        Assert.DoesNotContain("<script>", Html);
        Assert.Contains($"<meta http-equiv=\"Content-Security-Policy\" content=\"{PreviewPageBuilder.ContentSecurityPolicy}\">", Html);
    }

    [Theory]
    [InlineData("default-src 'none'")]
    [InlineData("script-src https://app.mdeditor.local/ https://*.plugin.mdeditor.local;")]
    [InlineData("connect-src 'none'")]
    [InlineData("frame-src 'none'")]
    [InlineData("object-src 'none'")]
    [InlineData("base-uri 'none'")]
    [InlineData("form-action 'none'")]
    public void Csp_restricts(string directive) =>
        Assert.Contains(directive, PreviewPageBuilder.ContentSecurityPolicy);

    [Fact]
    public void Csp_never_allows_inline_or_eval_script()
    {
        var script = PreviewPageBuilder.ContentSecurityPolicy.Split("; ").Single(d => d.StartsWith("script-src"));
        Assert.DoesNotContain("unsafe", script);
    }
}

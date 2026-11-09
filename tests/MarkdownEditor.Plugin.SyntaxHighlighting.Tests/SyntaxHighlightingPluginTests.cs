using Markdig;

namespace MarkdownEditor.Plugin.SyntaxHighlighting.Tests;

public class SyntaxHighlightingPluginTests
{
    private static string Read(string relativePath) =>
        File.ReadAllText(Path.Combine(AppContext.BaseDirectory, relativePath));

    [Fact]
    public void Rendering_is_unchanged_and_keeps_language_class()
    {
        var builder = new MarkdownPipelineBuilder();
        new SyntaxHighlightingPlugin().ConfigurePipeline(builder);

        Assert.Equal("<pre><code class=\"language-csharp\">var x = 1;\n</code></pre>\n",
            Markdown.ToHtml("```csharp\nvar x = 1;\n```", builder.Build()));
    }

    [Fact]
    public void Declared_assets_and_both_themes_exist()
    {
        var files = new SyntaxHighlightingPlugin().PreviewAssets.Select(a => a.RelativePath)
            .Concat([SyntaxHighlightingPlugin.LightThemePath, SyntaxHighlightingPlugin.DarkThemePath]);
        Assert.All(files, f => Assert.True(File.Exists(Path.Combine(AppContext.BaseDirectory, f)), f));
    }

    [Fact]
    public void Highlight_js_loads_before_bootstrap_script()
    {
        var scripts = new SyntaxHighlightingPlugin().PreviewAssets.Select(a => a.RelativePath).ToList();
        Assert.True(scripts.IndexOf(SyntaxHighlightingPlugin.HighlightJsPath) < scripts.IndexOf(SyntaxHighlightingPlugin.BootstrapScriptPath));
    }

    [Fact]
    public void Bundled_highlight_js_is_the_targeted_version() =>
        Assert.Contains($"Highlight.js v{SyntaxHighlightingPlugin.HighlightJsVersion}", Read(SyntaxHighlightingPlugin.HighlightJsPath));

    [Fact]
    public void Bootstrap_script_references_the_vendored_theme_folder() =>
        Assert.Contains($"vendor/highlightjs-{SyntaxHighlightingPlugin.HighlightJsVersion}/", Read(SyntaxHighlightingPlugin.BootstrapScriptPath));
}

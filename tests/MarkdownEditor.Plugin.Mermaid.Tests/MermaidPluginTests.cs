using Markdig;

namespace MarkdownEditor.Plugin.Mermaid.Tests;

public class MermaidPluginTests
{
    private static string Render(string markdown)
    {
        var builder = new MarkdownPipelineBuilder();
        new MermaidPlugin().ConfigurePipeline(builder);
        return Markdown.ToHtml(markdown, builder.Build());
    }

    [Fact]
    public void Mermaid_block_renders_escaped_source_in_diagram_container() =>
        Assert.Equal("<div class=\"mermaid-diagram\"><pre class=\"mermaid-source\">graph TD\nA--&gt;B&lt;br&gt;\n</pre></div>\n",
            Render("```mermaid\ngraph TD\nA-->B<br>\n```"));

    [Theory]
    [InlineData("```csharp\nx\n```", "<pre><code class=\"language-csharp\">x\n</code></pre>\n")]
    [InlineData("```Mermaid\nx\n```", "<pre><code class=\"language-Mermaid\">x\n</code></pre>\n")]
    [InlineData("```\nx\n```", "<pre><code>x\n</code></pre>\n")]
    [InlineData("    x", "<pre><code>x\n</code></pre>\n")]
    public void Other_code_blocks_render_as_commonmark(string markdown, string html) =>
        Assert.Equal(html, Render(markdown));

    [Fact]
    public void Info_string_attributes_after_language_still_match() =>
        Assert.StartsWith("<div class=\"mermaid-diagram\">", Render("```mermaid {theme=x}\nx\n```"));

    [Fact]
    public void Declared_assets_exist_with_mermaid_before_bootstrap()
    {
        var assets = new MermaidPlugin().PreviewAssets;
        Assert.All(assets, a => Assert.True(File.Exists(Path.Combine(AppContext.BaseDirectory, a.RelativePath)), a.RelativePath));
        Assert.True(assets.ToList().FindIndex(a => a.RelativePath == MermaidPlugin.MermaidScriptPath)
                    < assets.ToList().FindIndex(a => a.RelativePath == MermaidPlugin.BootstrapScriptPath));
    }

    [Fact]
    public void Bundled_mermaid_is_the_targeted_version()
    {
        var bundle = File.ReadAllText(Path.Combine(AppContext.BaseDirectory, MermaidPlugin.MermaidScriptPath));
        Assert.Contains($"\"{MermaidPlugin.MermaidVersion}\"", bundle);
        Assert.EndsWith("globalThis[\"mermaid\"] = globalThis.__esbuild_esm_mermaid_nm[\"mermaid\"].default;\n", bundle);
    }
}

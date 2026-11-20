using Markdig;

namespace MarkdownEditor.Plugin.Graphviz.Tests;

public class GraphvizPluginTests
{
    private static string Read(string relativePath) =>
        File.ReadAllText(Path.Combine(AppContext.BaseDirectory, relativePath));

    [Theory]
    [InlineData("dot")]
    [InlineData("graphviz")]
    public void Dot_blocks_keep_their_language_class_for_the_preview_script(string language)
    {
        var builder = new MarkdownPipelineBuilder();
        new GraphvizPlugin().ConfigurePipeline(builder);

        Assert.Equal($"<pre><code class=\"language-{language}\">digraph {{ a -&gt; b }}\n</code></pre>\n",
            Markdown.ToHtml($"```{language}\ndigraph {{ a -> b }}\n```", builder.Build()));
        Assert.Contains($"code.language-{language}", Read(GraphvizPlugin.BootstrapScriptPath));
    }

    [Fact]
    public void Declared_assets_exist_with_viz_before_bootstrap()
    {
        var paths = new GraphvizPlugin().PreviewAssets.Select(a => a.RelativePath).ToList();
        Assert.All(paths, p => Assert.True(File.Exists(Path.Combine(AppContext.BaseDirectory, p)), p));
        Assert.True(paths.IndexOf(GraphvizPlugin.VizScriptPath) < paths.IndexOf(GraphvizPlugin.BootstrapScriptPath));
    }

    [Fact]
    public void Bundled_viz_is_the_targeted_version_with_license_notice()
    {
        Assert.Contains($"Viz.js {GraphvizPlugin.VizVersion}", Read(GraphvizPlugin.VizScriptPath));
        Assert.Contains("Eclipse Public License", Read(Path.Combine(Path.GetDirectoryName(GraphvizPlugin.VizScriptPath)!, "NOTICE.txt")));
    }
}

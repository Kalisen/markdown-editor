using MarkdownEditor.Core.Rendering;
using MarkdownEditor.Core.Tests.Fakes;
using MarkdownEditor.Plugins.Abstractions.Preview;

namespace MarkdownEditor.Core.Tests.Rendering;

public class PreviewPageBuilderTests
{
    [Fact]
    public void Page_includes_theme_host_script_and_plugin_assets_served_from_plugin_host()
    {
        var plugin = new FakePlugin("demo", PreviewAsset.Stylesheet("a.css"), PreviewAsset.Script("/js/b.js"));

        var page = PreviewPageBuilder.Build(PreviewTheme.Dark, [plugin]);

        Assert.Contains("<html data-theme=\"dark\">", page);
        Assert.Contains("<link rel=\"stylesheet\" href=\"https://demo.plugin.mdeditor.local/a.css\">", page);
        Assert.Contains("<script src=\"https://demo.plugin.mdeditor.local/js/b.js\"></script>", page);
        Assert.True(page.IndexOf("window.mdeditor = {", StringComparison.Ordinal)
                    < page.IndexOf("js/b.js", StringComparison.Ordinal), "host API must load before plugin scripts");
    }
}

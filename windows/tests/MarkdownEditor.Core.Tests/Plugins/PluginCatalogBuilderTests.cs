using MarkdownEditor.Core.Plugins;
using MarkdownEditor.Core.Tests.Fakes;

namespace MarkdownEditor.Core.Tests.Plugins;

public class PluginCatalogBuilderTests
{
    [Fact]
    public void Valid_unique_plugins_are_accepted_invalid_and_duplicate_ids_rejected()
    {
        var builder = new PluginCatalogBuilder();
        var first = new FakePlugin("mermaid");

        builder.Add(first, "f1", "a.dll");
        builder.Add(new FakePlugin("mermaid"), "f2", "b.dll");
        builder.Add(new FakePlugin("Bad_Id"), "f3", "c.dll");
        var catalog = builder.Build();

        Assert.Equal([new LoadedPlugin(first, "f1")], catalog.Plugins);
        Assert.Equal(["b.dll", "c.dll"], catalog.Failures.Select(f => f.Source));
    }

    [Theory]
    [InlineData("images", true)]
    [InlineData("my-plugin2", true)]
    [InlineData("", false)]
    [InlineData("Upper", false)]
    [InlineData("-lead", false)]
    [InlineData("a--b", false)]
    [InlineData("dot.ted", false)]
    public void Plugin_id_rules(string id, bool valid) =>
        Assert.Equal(valid, MarkdownEditor.Plugins.Abstractions.PluginId.IsValid(id));
}

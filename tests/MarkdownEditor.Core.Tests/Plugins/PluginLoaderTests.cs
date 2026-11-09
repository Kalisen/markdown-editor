using MarkdownEditor.Core.Plugins;
using MarkdownEditor.Core.Rendering;

namespace MarkdownEditor.Core.Tests.Plugins;

public class PluginLoaderTests : IDisposable
{
    private const string StagedPlugins = "TestPlugins";
    private readonly string _root = Directory.CreateTempSubdirectory("mde-plugins-").FullName;

    public void Dispose() => Directory.Delete(_root, recursive: true);

    [Fact]
    public void Missing_plugins_folder_yields_empty_catalog() =>
        Assert.Same(PluginCatalog.Empty, new PluginLoader().LoadFrom(Path.Combine(_root, "absent")));

    [Fact]
    public void Loads_plugin_from_disk_sharing_contract_types_with_host()
    {
        var catalog = new PluginLoader().LoadFrom(Path.Combine(AppContext.BaseDirectory, StagedPlugins));

        Assert.Empty(catalog.Failures);
        var loaded = Assert.Single(catalog.Plugins);
        Assert.Equal("images", loaded.Plugin.Id);
        Assert.EndsWith("images", loaded.Folder);
        Assert.Contains("https://doc.mdeditor.local/a.png", new MarkdownRenderer([loaded.Plugin]).Render("![](a.png)"));
    }

    [Fact]
    public void Corrupt_assembly_is_reported_not_thrown()
    {
        var folder = Directory.CreateDirectory(Path.Combine(_root, "broken")).FullName;
        File.WriteAllText(Path.Combine(folder, "MarkdownEditor.Plugin.Broken.dll"), "not an assembly");

        var catalog = new PluginLoader().LoadFrom(_root);

        Assert.Empty(catalog.Plugins);
        Assert.EndsWith("MarkdownEditor.Plugin.Broken.dll", Assert.Single(catalog.Failures).Source);
    }
}

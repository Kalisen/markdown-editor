using MarkdownEditor.Plugins.Abstractions;

namespace MarkdownEditor.Core.Plugins;

/// <summary>Accumulates discovered plugins, rejecting invalid or duplicate identifiers.</summary>
internal sealed class PluginCatalogBuilder
{
    private readonly List<LoadedPlugin> _plugins = [];
    private readonly List<PluginLoadFailure> _failures = [];
    private readonly HashSet<string> _ids = new(StringComparer.Ordinal);

    public void Add(IMarkdownPlugin plugin, string folder, string source)
    {
        if (!PluginId.IsValid(plugin.Id))
            Fail(source, $"Invalid plugin id '{plugin.Id}'.");
        else if (!_ids.Add(plugin.Id))
            Fail(source, $"Duplicate plugin id '{plugin.Id}'.");
        else
            _plugins.Add(new LoadedPlugin(plugin, folder));
    }

    public void Fail(string source, string reason) => _failures.Add(new PluginLoadFailure(source, reason));

    public PluginCatalog Build() => new(_plugins.ToList(), _failures.ToList());
}

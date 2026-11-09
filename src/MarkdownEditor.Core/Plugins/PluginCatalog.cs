namespace MarkdownEditor.Core.Plugins;

/// <summary>Outcome of plugin discovery: plugins that loaded, and those that were skipped.</summary>
public sealed record PluginCatalog(IReadOnlyList<LoadedPlugin> Plugins, IReadOnlyList<PluginLoadFailure> Failures)
{
    public static PluginCatalog Empty { get; } = new([], []);
}

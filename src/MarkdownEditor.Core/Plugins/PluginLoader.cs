using System.Reflection;
using MarkdownEditor.Plugins.Abstractions;

namespace MarkdownEditor.Core.Plugins;

/// <summary>
/// Discovers plugins laid out as <c>&lt;pluginsRoot&gt;/&lt;folder&gt;/MarkdownEditor.Plugin.*.dll</c>.
/// Failures never propagate: they are reported in the returned catalog.
/// </summary>
public sealed class PluginLoader
{
    public const string PluginsFolderName = "plugins";
    public const string AssemblySearchPattern = "MarkdownEditor.Plugin.*.dll";

    public PluginCatalog LoadFrom(string pluginsRoot)
    {
        if (!Directory.Exists(pluginsRoot)) return PluginCatalog.Empty;

        var catalog = new PluginCatalogBuilder();
        foreach (var folder in Directory.EnumerateDirectories(pluginsRoot).Order(StringComparer.OrdinalIgnoreCase))
        foreach (var dll in Directory.EnumerateFiles(folder, AssemblySearchPattern))
        {
            try
            {
                var assembly = new PluginLoadContext(dll).LoadFromAssemblyPath(dll);
                foreach (var plugin in Instantiate(assembly)) catalog.Add(plugin, folder, dll);
            }
            catch (Exception ex)
            {
                catalog.Fail(dll, ex.GetBaseException().Message);
            }
        }
        return catalog.Build();
    }

    internal static IReadOnlyList<IMarkdownPlugin> Instantiate(Assembly assembly) =>
        assembly.GetExportedTypes()
            .Where(t => t is { IsClass: true, IsAbstract: false } && typeof(IMarkdownPlugin).IsAssignableFrom(t)
                        && t.GetConstructor(Type.EmptyTypes) is not null)
            .Select(t => (IMarkdownPlugin)Activator.CreateInstance(t)!)
            .ToList();
}

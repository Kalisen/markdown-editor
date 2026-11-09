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
        foreach (var folder in SafeEnumerate(catalog, pluginsRoot, Directory.GetDirectories).Order(StringComparer.OrdinalIgnoreCase))
        foreach (var dll in SafeEnumerate(catalog, folder, f => Directory.GetFiles(f, AssemblySearchPattern)))
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

    private static string[] SafeEnumerate(PluginCatalogBuilder catalog, string path, Func<string, string[]> list)
    {
        try
        {
            return list(path);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            catalog.Fail(path, ex.Message);
            return [];
        }
    }

    internal static IReadOnlyList<IMarkdownPlugin> Instantiate(Assembly assembly) =>
        assembly.GetExportedTypes()
            .Where(t => t is { IsClass: true, IsAbstract: false } && typeof(IMarkdownPlugin).IsAssignableFrom(t)
                        && t.GetConstructor(Type.EmptyTypes) is not null)
            .Select(t => (IMarkdownPlugin)Activator.CreateInstance(t)!)
            .ToList();
}

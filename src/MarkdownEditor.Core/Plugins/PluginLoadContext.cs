using System.Reflection;
using System.Runtime.Loader;

namespace MarkdownEditor.Core.Plugins;

/// <summary>
/// Isolates a plugin's private dependencies while sharing the contract assemblies
/// (Abstractions, Markdig) with the host so types unify.
/// </summary>
internal sealed class PluginLoadContext(string pluginAssemblyPath)
    : AssemblyLoadContext(Path.GetFileNameWithoutExtension(pluginAssemblyPath))
{
    internal static readonly IReadOnlySet<string> SharedAssemblies =
        new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "MarkdownEditor.Plugins.Abstractions", "Markdig" };

    private readonly AssemblyDependencyResolver _resolver = new(pluginAssemblyPath);

    protected override Assembly? Load(AssemblyName name)
    {
        if (name.Name is not null && SharedAssemblies.Contains(name.Name)) return null; // fall back to host
        var path = _resolver.ResolveAssemblyToPath(name);
        return path is null ? null : LoadFromAssemblyPath(path);
    }

    protected override IntPtr LoadUnmanagedDll(string unmanagedDllName)
    {
        var path = _resolver.ResolveUnmanagedDllToPath(unmanagedDllName);
        return path is null ? IntPtr.Zero : LoadUnmanagedDllFromPath(path);
    }
}

namespace MarkdownEditor.Plugins.Abstractions.Preview;

/// <summary>
/// Virtual host names served by the preview. Relative document resources are reachable under
/// <see cref="DocumentOrigin"/>; plugin assets under <see cref="PluginOrigin"/>.
/// </summary>
public static class PreviewHosts
{
    public const string Scheme = "https";
    public const string DocumentHost = "doc.mdeditor.local";
    public const string AppHost = "app.mdeditor.local";
    public const string PluginHostSuffix = ".plugin.mdeditor.local";

    public static string DocumentOrigin => $"{Scheme}://{DocumentHost}/";

    public static string AppOrigin => $"{Scheme}://{AppHost}/";

    public static string PluginHost(string pluginId) => pluginId + PluginHostSuffix;

    public static string PluginOrigin(string pluginId) => $"{Scheme}://{PluginHost(pluginId)}/";
}

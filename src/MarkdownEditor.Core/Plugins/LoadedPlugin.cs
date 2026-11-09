using MarkdownEditor.Plugins.Abstractions;

namespace MarkdownEditor.Core.Plugins;

/// <param name="Plugin">The plugin instance.</param>
/// <param name="Folder">Folder holding the plugin's files; served to the preview for its assets.</param>
public sealed record LoadedPlugin(IMarkdownPlugin Plugin, string Folder);

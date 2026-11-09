using Markdig;
using MarkdownEditor.Plugins.Abstractions.Preview;

namespace MarkdownEditor.Plugins.Abstractions;

/// <summary>
/// Contract implemented by every editor extension. A plugin assembly exposes one or more
/// public, parameterless implementations of this interface.
/// </summary>
public interface IMarkdownPlugin
{
    /// <summary>Stable identifier; lowercase letters, digits and hyphens (see <see cref="PluginId"/>).</summary>
    string Id { get; }

    string Name { get; }

    Version Version { get; }

    /// <summary>Adds parser/renderer extensions to the Markdown pipeline.</summary>
    void ConfigurePipeline(MarkdownPipelineBuilder builder);

    /// <summary>Scripts and stylesheets injected into the preview page.</summary>
    IReadOnlyList<PreviewAsset> PreviewAssets { get; }
}

using Markdig;
using MarkdownEditor.Plugins.Abstractions;
using MarkdownEditor.Plugins.Abstractions.Preview;

namespace MarkdownEditor.Plugin.Tables;

/// <summary>GitHub Flavored Markdown pipe tables, with column alignment.</summary>
public sealed class TablesPlugin : IMarkdownPlugin
{
    public const string PluginId = "tables";
    public const string StylesheetPath = "assets/tables.css";

    public string Id => PluginId;

    public string Name => "Tables (GFM)";

    public Version Version => new(1, 0, 0);

    public IReadOnlyList<PreviewAsset> PreviewAssets { get; } = [PreviewAsset.Stylesheet(StylesheetPath)];

    // GFM requires the delimiter row, so a header row alone is not a table.
    public void ConfigurePipeline(MarkdownPipelineBuilder builder) =>
        builder.UsePipeTables(new Markdig.Extensions.Tables.PipeTableOptions { RequireHeaderSeparator = true });
}

using Markdig.Syntax;
using Markdig;
using MarkdownEditor.Plugins.Abstractions;
using MarkdownEditor.Plugins.Abstractions.Preview;

namespace MarkdownEditor.Plugin.TaskLists;

/// <summary>GFM task list items: <c>- [ ] todo</c> / <c>- [x] done</c> render as (read-only) checkboxes.</summary>
public sealed class TaskListsPlugin : IMarkdownPlugin, IDocumentFeatureProbe
{
    public const string PluginId = "task-lists";
    public const string StylesheetPath = "assets/task-lists.css";

    public string Id => PluginId;

    public string Name => "Task lists (GFM)";

    public Version Version => new(1, 0, 0);

    public IReadOnlyList<PreviewAsset> PreviewAssets { get; } = [PreviewAsset.Stylesheet(StylesheetPath)];

    public bool IsUsedBy(MarkdownDocument document) =>
        document.Descendants<Markdig.Extensions.TaskLists.TaskList>().Any();

    public void ConfigurePipeline(MarkdownPipelineBuilder builder) => builder.UseTaskLists();
}

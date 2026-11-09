using Markdig;
using MarkdownEditor.Plugins.Abstractions;
using MarkdownEditor.Plugins.Abstractions.Preview;

namespace MarkdownEditor.Plugin.Images;

/// <summary>
/// Picture rendering: resolves relative image paths against the document folder and
/// supports size hints in the image title, e.g. <c>![alt](a.png "=200x100")</c>.
/// </summary>
public sealed class ImagesPlugin : IMarkdownPlugin
{
    public const string PluginId = "images";
    public const string StylesheetPath = "assets/images.css";

    public string Id => PluginId;

    public string Name => "Pictures";

    public Version Version => new(1, 0, 0);

    public IReadOnlyList<PreviewAsset> PreviewAssets { get; } = [PreviewAsset.Stylesheet(StylesheetPath)];

    public void ConfigurePipeline(MarkdownPipelineBuilder builder) =>
        builder.Extensions.AddIfNotAlready<ImageExtension>();
}

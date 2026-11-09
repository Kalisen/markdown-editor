using Markdig;
using MarkdownEditor.Plugins.Abstractions;
using MarkdownEditor.Plugins.Abstractions.Preview;

namespace MarkdownEditor.Core.Tests.Fakes;

internal sealed class FakePlugin(string id, params PreviewAsset[] assets) : IMarkdownPlugin
{
    public Action<MarkdownPipelineBuilder> Configure { get; init; } = _ => { };

    public string Id => id;

    public string Name => id;

    public Version Version => new(1, 0);

    public IReadOnlyList<PreviewAsset> PreviewAssets => assets;

    public void ConfigurePipeline(MarkdownPipelineBuilder builder) => Configure(builder);
}

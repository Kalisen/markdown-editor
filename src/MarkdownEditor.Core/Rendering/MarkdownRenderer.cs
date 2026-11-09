using Markdig;
using MarkdownEditor.Core.Plugins;
using MarkdownEditor.Plugins.Abstractions;

namespace MarkdownEditor.Core.Rendering;

/// <summary>
/// Converts Markdown to HTML. The base pipeline is strict CommonMark; plugins add extensions.
/// A plugin throwing while configuring the pipeline is excluded and reported in <see cref="Failures"/>.
/// </summary>
public sealed class MarkdownRenderer
{
    private readonly MarkdownPipeline _pipeline;

    public MarkdownRenderer(IEnumerable<IMarkdownPlugin>? plugins = null)
    {
        var failures = new List<PluginLoadFailure>();
        var active = new List<IMarkdownPlugin>();
        var builder = new MarkdownPipelineBuilder();
        foreach (var plugin in plugins ?? [])
        {
            // Configure on a probe builder first so a failing plugin cannot leave the real one half-configured.
            try
            {
                plugin.ConfigurePipeline(new MarkdownPipelineBuilder());
                plugin.ConfigurePipeline(builder);
                active.Add(plugin);
            }
            catch (Exception ex)
            {
                failures.Add(new PluginLoadFailure(plugin.Id, ex.Message));
            }
        }
        _pipeline = builder.Build();
        ActivePlugins = active;
        Failures = failures;
    }

    public IReadOnlyList<IMarkdownPlugin> ActivePlugins { get; }

    public IReadOnlyList<PluginLoadFailure> Failures { get; }

    public string Render(string markdown) => Markdown.ToHtml(markdown, _pipeline);
}

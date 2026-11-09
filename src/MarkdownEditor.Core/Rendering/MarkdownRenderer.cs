using Markdig;
using Markdig.Renderers;
using Markdig.Syntax;
using MarkdownEditor.Core.Plugins;
using MarkdownEditor.Plugins.Abstractions;

namespace MarkdownEditor.Core.Rendering;

/// <param name="Html">The rendered HTML.</param>
/// <param name="UsedPlugins">Plugins whose <see cref="IDocumentFeatureProbe"/> reports they apply to the document.</param>
public sealed record RenderResult(string Html, IReadOnlyList<IMarkdownPlugin> UsedPlugins);

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

    /// <summary>Plugins loaded and configured into the pipeline.</summary>
    public IReadOnlyList<IMarkdownPlugin> ActivePlugins { get; }

    public IReadOnlyList<PluginLoadFailure> Failures { get; }

    public string Render(string markdown) => RenderDocument(markdown).Html;

    /// <summary>Parses once and uses the same syntax tree for the HTML and for plugin usage detection.</summary>
    public RenderResult RenderDocument(string markdown)
    {
        var document = Markdown.Parse(markdown, _pipeline);
        using var writer = new StringWriter();
        var renderer = new HtmlRenderer(writer);
        _pipeline.Setup(renderer);
        renderer.Render(document);
        writer.Flush();
        return new RenderResult(writer.ToString(), ActivePlugins.Where(p => IsUsed(p, document)).ToList());
    }

    /// <summary>A failing probe only means the plugin is not reported; rendering is unaffected.</summary>
    private static bool IsUsed(IMarkdownPlugin plugin, MarkdownDocument document)
    {
        try
        {
            return plugin is IDocumentFeatureProbe probe && probe.IsUsedBy(document);
        }
        catch (Exception)
        {
            return false;
        }
    }
}

using Markdig.Syntax;
using System.Net;
using Markdig;
using Markdig.Extensions.Yaml;
using Markdig.Renderers;
using Markdig.Renderers.Html;
using MarkdownEditor.Plugins.Abstractions;
using MarkdownEditor.Plugins.Abstractions.Preview;

namespace MarkdownEditor.Plugin.FrontMatter;

/// <summary>
/// YAML front matter (<c>---</c> … <c>---</c> at the start of the document) is shown as a table of its
/// top-level keys, as on GitHub, instead of being rendered as text.
/// </summary>
public sealed class FrontMatterPlugin : IMarkdownPlugin, IDocumentFeatureProbe
{
    public const string PluginId = "front-matter";
    public const string StylesheetPath = "assets/front-matter.css";

    public string Id => PluginId;

    public string Name => "Front matter";

    public Version Version => new(1, 0, 0);

    public IReadOnlyList<PreviewAsset> PreviewAssets { get; } = [PreviewAsset.Stylesheet(StylesheetPath)];

    public bool IsUsedBy(MarkdownDocument document) =>
        document.Descendants<YamlFrontMatterBlock>().Any(b => FrontMatterYaml.Parse(b.Lines.ToString()).Count > 0);

    public void ConfigurePipeline(MarkdownPipelineBuilder builder)
    {
        builder.UseYamlFrontMatter();
        builder.Extensions.AddIfNotAlready<FrontMatterTableExtension>();
    }
}

internal sealed class FrontMatterTableExtension : IMarkdownExtension
{
    public void Setup(MarkdownPipelineBuilder pipeline)
    {
    }

    // Runs after the YAML extension, replacing its renderer (which writes nothing).
    public void Setup(MarkdownPipeline pipeline, IMarkdownRenderer renderer)
    {
        if (renderer is HtmlRenderer html)
            html.ObjectRenderers.ReplaceOrAdd<YamlFrontMatterHtmlRenderer>(new FrontMatterTableRenderer());
    }
}

internal sealed class FrontMatterTableRenderer : HtmlObjectRenderer<YamlFrontMatterBlock>
{
    public const string TableClass = "front-matter";

    protected override void Write(HtmlRenderer renderer, YamlFrontMatterBlock block)
    {
        var entries = FrontMatterYaml.Parse(block.Lines.ToString());
        if (entries.Count == 0) return;

        renderer.EnsureLine();
        renderer.Write("<table class=\"").Write(TableClass).WriteLine("\">");
        renderer.WriteLine("<thead>").WriteLine("<tr>");
        foreach (var entry in entries) renderer.Write("<th>").Write(Encode(entry.Key)).WriteLine("</th>");
        renderer.WriteLine("</tr>").WriteLine("</thead>").WriteLine("<tbody>").WriteLine("<tr>");
        foreach (var entry in entries)
        {
            renderer.Write("<td>");
            if (entry.IsRaw)
            {
                renderer.Write("<pre><code>").Write(Encode(entry.Values[0])).Write("</code></pre>");
            }
            else if (entry.Values.Count == 1)
            {
                renderer.Write(Encode(entry.Values[0]));
            }
            else if (entry.Values.Count > 1)
            {
                renderer.Write("<ul>");
                foreach (var value in entry.Values) renderer.Write("<li>").Write(Encode(value)).Write("</li>");
                renderer.Write("</ul>");
            }
            renderer.WriteLine("</td>");
        }
        renderer.WriteLine("</tr>").WriteLine("</tbody>").WriteLine("</table>");
    }

    private static string Encode(string text) => WebUtility.HtmlEncode(text);
}

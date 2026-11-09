using Markdig.Syntax;

namespace MarkdownEditor.Plugins.Abstractions;

/// <summary>
/// Optional contract for an <see cref="IMarkdownPlugin"/>: reports whether the plugin applies to a parsed
/// document (e.g. the document contains a table), so the editor can show which extensions are in use.
/// Plugins that do not implement it are never reported as in use.
/// </summary>
public interface IDocumentFeatureProbe
{
    /// <param name="document">The document parsed with the full pipeline (all plugins' extensions).</param>
    bool IsUsedBy(MarkdownDocument document);
}

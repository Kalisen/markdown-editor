namespace MarkdownEditor.Core.Documents;

/// <summary>File types the editor opens and saves.</summary>
public static class DocumentFileTypes
{
    public const string DefaultExtension = ".md";

    public static readonly IReadOnlyList<string> MarkdownExtensions = [".md", ".markdown", ".mdown", ".mkd"];

    public const string DialogFilter =
        "Markdown files (*.md;*.markdown;*.mdown;*.mkd)|*.md;*.markdown;*.mdown;*.mkd|Text files (*.txt)|*.txt|All files (*.*)|*.*";
}

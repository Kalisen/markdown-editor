namespace MarkdownEditor.Core.Documents;

/// <summary>An open Markdown document. <see cref="FilePath"/> is null until first saved.</summary>
public sealed class MarkdownDocument
{
    public const string UntitledName = "Untitled";

    private string _text;
    private string _savedText;

    public MarkdownDocument(string? filePath = null, string text = "")
    {
        FilePath = filePath;
        _text = text;
        _savedText = text;
    }

    public string? FilePath { get; private set; }

    public string DisplayName => FilePath is null ? UntitledName : Path.GetFileName(FilePath);

    public string? Directory => FilePath is null ? null : Path.GetDirectoryName(FilePath);

    public string Text
    {
        get => _text;
        set => _text = value;
    }

    public bool IsDirty => !string.Equals(_text, _savedText, StringComparison.Ordinal);

    public void MarkSaved(string filePath)
    {
        FilePath = filePath;
        _savedText = _text;
    }
}

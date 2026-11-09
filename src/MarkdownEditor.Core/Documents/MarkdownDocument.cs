using System.Runtime.InteropServices;
using System.Security.Cryptography;

namespace MarkdownEditor.Core.Documents;

/// <summary>An open Markdown document. <see cref="FilePath"/> is null until first saved.</summary>
public sealed class MarkdownDocument
{
    public const string UntitledName = "Untitled";

    private string _text;
    private bool _isDirty;

    // The saved state is kept as a fingerprint rather than a second full copy of the text.
    private int _savedLength;
    private byte[] _savedHash;

    public MarkdownDocument(string? filePath = null, string text = "")
    {
        FilePath = filePath;
        _text = text;
        _savedLength = text.Length;
        _savedHash = Hash(text);
    }

    public string? FilePath { get; private set; }

    public string DisplayName => FilePath is null ? UntitledName : Path.GetFileName(FilePath);

    public string? Directory => FilePath is null ? null : Path.GetDirectoryName(FilePath);

    public string Text
    {
        get => _text;
        set
        {
            _text = value;
            _isDirty = value.Length != _savedLength || !Hash(value).AsSpan().SequenceEqual(_savedHash);
        }
    }

    public bool IsDirty => _isDirty;

    public void MarkSaved(string filePath)
    {
        FilePath = filePath;
        _savedLength = _text.Length;
        _savedHash = Hash(_text);
        _isDirty = false;
    }

    private static byte[] Hash(string text) => SHA256.HashData(MemoryMarshal.AsBytes(text.AsSpan()));
}

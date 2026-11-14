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
            _isDirty = !MatchesSaved(value);
        }
    }

    public bool IsDirty => _isDirty;

    /// <returns>True when <paramref name="text"/> is what was last loaded from or saved to the file.</returns>
    public bool MatchesSaved(string text) =>
        text.Length == _savedLength && Hash(text).AsSpan().SequenceEqual(_savedHash);

    public void MarkSaved(string filePath)
    {
        FilePath = filePath;
        _savedLength = _text.Length;
        _savedHash = Hash(_text);
        _isDirty = false;
    }

    /// <summary>
    /// Records that the file now holds <paramref name="diskText"/> while this document keeps its own text:
    /// the document is dirty for as long as it differs from the file.
    /// </summary>
    public void MarkChangedOnDisk(string diskText)
    {
        _savedLength = diskText.Length;
        _savedHash = Hash(diskText);
        _isDirty = !MatchesSaved(_text);
    }

    private static byte[] Hash(string text) => SHA256.HashData(MemoryMarshal.AsBytes(text.AsSpan()));
}

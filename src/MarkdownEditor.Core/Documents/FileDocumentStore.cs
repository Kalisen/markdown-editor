using System.Text;

namespace MarkdownEditor.Core.Documents;

/// <summary>Reads with BOM detection (UTF-8 default); writes UTF-8 without BOM. Line endings are preserved.</summary>
public sealed class FileDocumentStore : IDocumentStore
{
    private static readonly Encoding Utf8NoBom = new UTF8Encoding(encoderShouldEmitUTF8Identifier: false);

    public async Task<string> ReadAsync(string path, CancellationToken ct = default)
    {
        using var reader = new StreamReader(path, Utf8NoBom, detectEncodingFromByteOrderMarks: true);
        return await reader.ReadToEndAsync(ct);
    }

    public Task WriteAsync(string path, string text, CancellationToken ct = default) =>
        File.WriteAllTextAsync(path, text, Utf8NoBom, ct);
}

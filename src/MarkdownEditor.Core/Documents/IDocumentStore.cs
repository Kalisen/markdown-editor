namespace MarkdownEditor.Core.Documents;

public interface IDocumentStore
{
    Task<string> ReadAsync(string path, CancellationToken ct = default);

    Task WriteAsync(string path, string text, CancellationToken ct = default);
}

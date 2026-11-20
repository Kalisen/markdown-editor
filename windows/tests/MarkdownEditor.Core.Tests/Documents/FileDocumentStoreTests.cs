using System.Text;
using MarkdownEditor.Core.Documents;

namespace MarkdownEditor.Core.Tests.Documents;

public class FileDocumentStoreTests : IDisposable
{
    private readonly string _path = Path.GetTempFileName();

    public void Dispose() => File.Delete(_path);

    [Fact]
    public async Task Writes_utf8_without_bom_preserving_line_endings_and_reads_back()
    {
        var store = new FileDocumentStore();
        const string text = "é\r\nb\nc";

        await store.WriteAsync(_path, text, TestContext.Current.CancellationToken);

        Assert.Equal(Encoding.UTF8.GetBytes(text), await File.ReadAllBytesAsync(_path, TestContext.Current.CancellationToken));
        Assert.Equal(text, await store.ReadAsync(_path, TestContext.Current.CancellationToken));
    }

    [Fact]
    public async Task Reads_utf16_file_with_bom()
    {
        await File.WriteAllTextAsync(_path, "ü", Encoding.Unicode, TestContext.Current.CancellationToken);
        Assert.Equal("ü", await new FileDocumentStore().ReadAsync(_path, TestContext.Current.CancellationToken));
    }
}

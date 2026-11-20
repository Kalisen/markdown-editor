using MarkdownEditor.Core.Documents;

namespace MarkdownEditor.Core.Tests.Documents;

public sealed class FileDocumentWatcherTests : IDisposable
{
    private static readonly TimeSpan EventTimeout = TimeSpan.FromSeconds(10);
    private static readonly TimeSpan QuietPeriod = TimeSpan.FromMilliseconds(500);

    private readonly string _folder = Directory.CreateTempSubdirectory("md-watcher-").FullName;
    private readonly FileDocumentWatcher _watcher = new();
    private readonly SemaphoreSlim _changed = new(0);
    private readonly string _path;

    public FileDocumentWatcherTests()
    {
        _path = Path.Combine(_folder, "doc.md");
        File.WriteAllText(_path, "one");
        _watcher.Changed += (_, _) => _changed.Release();
    }

    public void Dispose()
    {
        _watcher.Dispose();
        Directory.Delete(_folder, recursive: true);
    }

    [Fact]
    public async Task Signals_when_the_watched_file_is_rewritten()
    {
        _watcher.Watch(_path);

        await File.WriteAllTextAsync(_path, "two", TestContext.Current.CancellationToken);

        Assert.True(await _changed.WaitAsync(EventTimeout, TestContext.Current.CancellationToken));
    }

    [Fact]
    public async Task Signals_when_the_watched_file_is_replaced_by_a_rename()
    {
        _watcher.Watch(_path);
        var temp = Path.Combine(_folder, "doc.md.tmp");
        await File.WriteAllTextAsync(temp, "two", TestContext.Current.CancellationToken);

        File.Move(temp, _path, overwrite: true);

        Assert.True(await _changed.WaitAsync(EventTimeout, TestContext.Current.CancellationToken));
    }

    [Fact]
    public async Task Stays_silent_for_other_files_and_after_watching_stops()
    {
        _watcher.Watch(_path);
        await File.WriteAllTextAsync(Path.Combine(_folder, "other.md"), "x", TestContext.Current.CancellationToken);
        _watcher.Watch(null);
        await File.WriteAllTextAsync(_path, "two", TestContext.Current.CancellationToken);

        Assert.False(await _changed.WaitAsync(QuietPeriod, TestContext.Current.CancellationToken));
    }
}

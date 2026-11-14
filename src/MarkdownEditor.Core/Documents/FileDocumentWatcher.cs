namespace MarkdownEditor.Core.Documents;

/// <summary>
/// Watches the document file through the file system. Creation and renames are included because many programs
/// save by writing a temporary file and renaming it over the original.
/// </summary>
public sealed class FileDocumentWatcher : IDocumentWatcher, IDisposable
{
    private const NotifyFilters WatchedChanges =
        NotifyFilters.LastWrite | NotifyFilters.Size | NotifyFilters.FileName | NotifyFilters.CreationTime;

    private FileSystemWatcher? _watcher;

    public event EventHandler? Changed;

    public void Watch(string? path)
    {
        _watcher?.Dispose();
        _watcher = null;
        if (path is null || Path.GetDirectoryName(path) is not { Length: > 0 } directory) return;
        try
        {
            var watcher = new FileSystemWatcher(directory, Path.GetFileName(path)) { NotifyFilter = WatchedChanges };
            watcher.Changed += OnFileEvent;
            watcher.Created += OnFileEvent;
            watcher.Renamed += OnFileEvent;
            watcher.EnableRaisingEvents = true;
            _watcher = watcher;
        }
        catch (Exception ex) when (ex is IOException or ArgumentException)
        {
            // The folder cannot be watched (e.g. it is gone, or an unsupported file system):
            // changes are then only noticed when the app checks on its own.
        }
    }

    public void Dispose() => Watch(null);

    private void OnFileEvent(object sender, FileSystemEventArgs e) => Changed?.Invoke(this, EventArgs.Empty);
}

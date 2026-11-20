using MarkdownEditor.Core.Documents;
using MarkdownEditor.Core.Editing;

namespace MarkdownEditor.Core.Tests.Editing;

public class EditorSessionTests
{
    private const string PathA = @"C:\docs\a.md";
    private const string PathB = @"C:\docs\b.md";

    private sealed class MemoryStore : IDocumentStore
    {
        public Dictionary<string, string> Files { get; } = new(StringComparer.OrdinalIgnoreCase);
        public bool FailWrites { get; set; }

        public Task<string> ReadAsync(string path, CancellationToken ct = default) =>
            Files.TryGetValue(path, out var t) ? Task.FromResult(t) : throw new FileNotFoundException("missing");

        public Task WriteAsync(string path, string text, CancellationToken ct = default)
        {
            if (FailWrites) throw new IOException("disk full");
            Files[path] = text;
            return Task.CompletedTask;
        }
    }

    private sealed class ScriptedPrompts : IUserPrompts
    {
        public string? OpenPath { get; set; }
        public string? SavePath { get; set; }
        public UnsavedChangesDecision Decision { get; set; }
        public int UnsavedAsked { get; private set; }
        public string? SuggestedName { get; private set; }
        public List<string> Errors { get; } = [];

        public string? AskOpenPath() => OpenPath;

        public string? AskSavePath(string suggestedName)
        {
            SuggestedName = suggestedName;
            return SavePath;
        }

        public string? AskExportPath(string suggestedName, MarkdownEditor.Core.Export.ExportFormat format) => null;

        public UnsavedChangesDecision AskUnsavedChanges(string documentName)
        {
            UnsavedAsked++;
            return Decision;
        }

        public bool Reload { get; set; }
        public List<bool> ChangedFileAsked { get; } = [];
        public int ReloadDiscardAsked { get; private set; }

        public bool AskReloadChangedFile(bool hasUnsavedChanges)
        {
            ChangedFileAsked.Add(hasUnsavedChanges);
            return Reload;
        }

        public bool AskReloadDiscardingChanges(string documentName)
        {
            ReloadDiscardAsked++;
            return Reload;
        }

        public void ShowError(string message) => Errors.Add(message);
    }

    private sealed class FakeWatcher : IDocumentWatcher
    {
        public event EventHandler? Changed;

        public string? Watched { get; private set; }

        public void Watch(string? path) => Watched = path;

        public void Raise() => Changed?.Invoke(this, EventArgs.Empty);
    }

    private readonly MemoryStore _store = new() { Files = { [PathA] = "# A" } };
    private readonly ScriptedPrompts _prompts = new();
    private readonly FakeWatcher _watcher = new();
    private readonly EditorSession _session;

    public EditorSessionTests() => _session = new EditorSession(_store, _prompts, _watcher);

    [Fact]
    public async Task Open_loads_file_via_prompt_and_raises_change()
    {
        var raised = 0;
        _session.DocumentChanged += (_, _) => raised++;
        _prompts.OpenPath = PathA;

        Assert.True(await _session.OpenAsync());

        Assert.Equal((PathA, "# A", false, 1), (_session.Document.FilePath, _session.Document.Text, _session.Document.IsDirty, raised));
    }

    [Fact]
    public async Task Open_cancelled_or_failing_keeps_current_document()
    {
        var before = _session.Document;
        Assert.False(await _session.OpenAsync());
        Assert.False(await _session.OpenAsync(PathB));
        Assert.Same(before, _session.Document);
        Assert.Single(_prompts.Errors);
    }

    [Fact]
    public async Task Save_untitled_asks_for_path_with_default_name()
    {
        _session.Document.Text = "x";
        _prompts.SavePath = PathB;

        Assert.True(await _session.SaveAsync());

        Assert.Equal("Untitled.md", _prompts.SuggestedName);
        Assert.Equal("x", _store.Files[PathB]);
        Assert.Equal((PathB, false), (_session.Document.FilePath, _session.Document.IsDirty));
    }

    [Fact]
    public async Task Save_existing_writes_without_prompt()
    {
        await _session.OpenAsync(PathA);
        _session.Document.Text = "changed";

        Assert.True(await _session.SaveAsync());

        Assert.Null(_prompts.SuggestedName);
        Assert.Equal("changed", _store.Files[PathA]);
    }

    [Fact]
    public async Task Save_failure_reports_error_and_stays_dirty()
    {
        await _session.OpenAsync(PathA);
        _session.Document.Text = "changed";
        _store.FailWrites = true;

        Assert.False(await _session.SaveAsync());

        Assert.True(_session.Document.IsDirty);
        Assert.Single(_prompts.Errors);
    }

    [Fact]
    public async Task Clean_document_is_discarded_without_asking()
    {
        Assert.True(await _session.NewAsync());
        Assert.Equal(0, _prompts.UnsavedAsked);
    }

    [Theory]
    [InlineData(UnsavedChangesDecision.Discard, true, false)]
    [InlineData(UnsavedChangesDecision.Cancel, false, false)]
    [InlineData(UnsavedChangesDecision.Save, true, true)]
    public async Task Dirty_document_decision_controls_new(UnsavedChangesDecision decision, bool proceeds, bool saved)
    {
        await _session.OpenAsync(PathA);
        _session.Document.Text = "edited";
        _prompts.Decision = decision;

        Assert.Equal(proceeds, await _session.NewAsync());

        Assert.Equal(saved, _store.Files[PathA] == "edited");
        Assert.Equal(proceeds ? null : PathA, _session.Document.FilePath);
    }

    [Fact]
    public async Task Watcher_follows_the_document_file_and_its_hints_are_forwarded()
    {
        var hints = 0;
        _session.ExternalChangeSuspected += (_, _) => hints++;

        await _session.OpenAsync(PathA);
        Assert.Equal(PathA, _watcher.Watched);

        _prompts.SavePath = PathB;
        await _session.SaveAsAsync();
        Assert.Equal(PathB, _watcher.Watched);

        await _session.NewAsync();
        Assert.Null(_watcher.Watched);

        _watcher.Raise();
        Assert.Equal(1, hints);
    }

    [Fact]
    public async Task External_change_accepted_reloads_the_file()
    {
        await _session.OpenAsync(PathA);
        _store.Files[PathA] = "# external";
        _prompts.Reload = true;

        Assert.True(await _session.CheckForExternalChangeAsync());

        Assert.Equal(("# external", false), (_session.Document.Text, _session.Document.IsDirty));
        Assert.Equal([false], _prompts.ChangedFileAsked);
    }

    [Fact]
    public async Task External_change_declined_keeps_text_as_unsaved_and_is_not_offered_again()
    {
        await _session.OpenAsync(PathA);
        _store.Files[PathA] = "# external";

        Assert.False(await _session.CheckForExternalChangeAsync());
        Assert.False(await _session.CheckForExternalChangeAsync());

        Assert.Equal(("# A", true), (_session.Document.Text, _session.Document.IsDirty));
        Assert.Single(_prompts.ChangedFileAsked);
    }

    [Fact]
    public async Task External_change_prompt_warns_about_unsaved_changes()
    {
        await _session.OpenAsync(PathA);
        _session.Document.Text = "edited";
        _store.Files[PathA] = "# external";

        await _session.CheckForExternalChangeAsync();

        Assert.Equal([true], _prompts.ChangedFileAsked);
    }

    [Fact]
    public async Task Own_save_missing_file_or_untitled_document_is_not_an_external_change()
    {
        Assert.False(await _session.CheckForExternalChangeAsync()); // untitled

        await _session.OpenAsync(PathA);
        _session.Document.Text = "changed";
        await _session.SaveAsync();
        Assert.False(await _session.CheckForExternalChangeAsync()); // own save

        _store.Files.Remove(PathA);
        Assert.False(await _session.CheckForExternalChangeAsync()); // deleted

        Assert.Empty(_prompts.ChangedFileAsked);
        Assert.Empty(_prompts.Errors);
    }

    [Fact]
    public async Task External_change_is_not_checked_while_another_operation_awaits_the_user()
    {
        await _session.OpenAsync(PathA);
        _store.Files[PathA] = "# external";
        _prompts.Reload = true;
        var checkedDuringSave = false;
        _session.DocumentChanged += async (_, _) => checkedDuringSave = await _session.CheckForExternalChangeAsync();

        _session.Document.Text = "mine";
        await _session.SaveAsync();

        Assert.False(checkedDuringSave);
        Assert.Equal("mine", _session.Document.Text);
    }

    [Fact]
    public async Task Reload_rereads_a_clean_document_without_asking()
    {
        await _session.OpenAsync(PathA);
        _store.Files[PathA] = "# external";

        Assert.True(await _session.ReloadAsync());

        Assert.Equal("# external", _session.Document.Text);
        Assert.Equal(0, _prompts.ReloadDiscardAsked);
    }

    [Theory]
    [InlineData(true, "# A")]
    [InlineData(false, "edited")]
    public async Task Reload_of_dirty_document_needs_confirmation(bool confirmed, string expectedText)
    {
        await _session.OpenAsync(PathA);
        _session.Document.Text = "edited";
        _prompts.Reload = confirmed;

        Assert.Equal(confirmed, await _session.ReloadAsync());

        Assert.Equal(expectedText, _session.Document.Text);
    }

    [Fact]
    public async Task Reload_does_nothing_for_untitled_document_and_reports_unreadable_file()
    {
        Assert.False(await _session.ReloadAsync());
        Assert.Empty(_prompts.Errors);

        await _session.OpenAsync(PathA);
        _store.Files.Remove(PathA);

        Assert.False(await _session.ReloadAsync());
        Assert.Single(_prompts.Errors);
    }
}

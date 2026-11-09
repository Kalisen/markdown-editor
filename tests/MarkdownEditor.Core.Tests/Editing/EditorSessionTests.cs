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

        public UnsavedChangesDecision AskUnsavedChanges(string documentName)
        {
            UnsavedAsked++;
            return Decision;
        }

        public void ShowError(string message) => Errors.Add(message);
    }

    private readonly MemoryStore _store = new() { Files = { [PathA] = "# A" } };
    private readonly ScriptedPrompts _prompts = new();
    private readonly EditorSession _session;

    public EditorSessionTests() => _session = new EditorSession(_store, _prompts);

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
}

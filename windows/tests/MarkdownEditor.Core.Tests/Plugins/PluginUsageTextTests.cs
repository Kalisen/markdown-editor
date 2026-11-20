using MarkdownEditor.Core.Plugins;
using MarkdownEditor.Core.Tests.Fakes;

namespace MarkdownEditor.Core.Tests.Plugins;

public class PluginUsageTextTests
{
    private static readonly FakePlugin Tables = new("tables");
    private static readonly FakePlugin Math = new("math");
    private static readonly FakePlugin Emoji = new("emoji");

    [Fact]
    public void Describe_lists_used_extensions_alphabetically() =>
        Assert.Equal("Extensions: math · tables", PluginUsageText.Describe([Tables, Math]));

    [Fact]
    public void Describe_without_extensions_says_commonmark_only() =>
        Assert.Equal("Extensions: none (CommonMark only)", PluginUsageText.Describe([]));

    [Fact]
    public void Details_marks_used_plugins_among_loaded_ones() =>
        Assert.Equal($"○ emoji{Environment.NewLine}● math{Environment.NewLine}○ tables",
            PluginUsageText.Details([Tables, Math, Emoji], [Math]));
}

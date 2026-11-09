using System.Text.Json;
using System.Text.RegularExpressions;
using MarkdownEditor.Core.Rendering;

namespace MarkdownEditor.Core.Tests.Rendering;

/// <summary>Runs every example of the CommonMark 0.31.2 specification against the core renderer.</summary>
public partial class CommonMarkSpecTests
{
    private const string SpecFile = "Spec/commonmark-0.31.2.json";
    private static readonly MarkdownRenderer Renderer = new();

    public sealed record SpecExample(string Markdown, string Html, int Example, string Section)
    {
        public override string ToString() => $"#{Example} {Section}";
    }

    public static TheoryData<SpecExample> Examples()
    {
        var json = File.ReadAllText(Path.Combine(AppContext.BaseDirectory, SpecFile));
        var examples = JsonSerializer.Deserialize<List<SpecExample>>(json, JsonSerializerOptions.Web)!;
        return new TheoryData<SpecExample>(examples);
    }

    [Theory]
    [MemberData(nameof(Examples))]
    public void Example_renders_as_specified(SpecExample example) =>
        Assert.Equal(Normalize(example.Html), Normalize(Renderer.Render(example.Markdown)));

    /// <summary>
    /// Like the spec's reference harness (normalize.py), ignores newlines between adjacent tags,
    /// which carry no meaning in rendered HTML.
    /// </summary>
    private static string Normalize(string html) => BetweenTags().Replace(html, "><");

    [GeneratedRegex(@">\n+<")]
    private static partial Regex BetweenTags();
}

using System.Text.Json;
using System.Text.RegularExpressions;

namespace MarkdownEditor.Tests.Shared;

/// <summary>
/// Extension examples from the GitHub Flavored Markdown spec 0.29 (github/cmark-gfm test/spec.txt),
/// extracted to Spec/gfm-0.29-extensions.json.
/// </summary>
public static partial class GfmSpec
{
    private const string SpecFile = "Spec/gfm-0.29-extensions.json";

    public sealed record Example(string Extension, int Number, string Markdown, string Html)
    {
        public override string ToString() => $"GFM #{Number} ({Extension})";
    }

    private sealed record RawExample(string Extension, int Example, string Markdown, string Html);

    public static TheoryData<Example> For(string extension)
    {
        var json = File.ReadAllText(Path.Combine(AppContext.BaseDirectory, SpecFile));
        var examples = JsonSerializer.Deserialize<List<RawExample>>(json, JsonSerializerOptions.Web)!
            .Where(e => e.Extension == extension)
            .Select(e => new Example(e.Extension, e.Example, e.Markdown, e.Html));
        return new TheoryData<Example>(examples);
    }

    /// <summary>Ignores newlines between adjacent tags, like the spec's reference harness.</summary>
    public static string Normalize(string html) => BetweenTags().Replace(html, "><");

    [GeneratedRegex(@">\n+<")]
    private static partial Regex BetweenTags();
}

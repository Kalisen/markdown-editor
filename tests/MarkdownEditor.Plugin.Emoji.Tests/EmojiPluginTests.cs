using Markdig;

namespace MarkdownEditor.Plugin.Emoji.Tests;

public class EmojiPluginTests
{
    private static string Render(string markdown)
    {
        var builder = new MarkdownPipelineBuilder();
        new EmojiPlugin().ConfigurePipeline(builder);
        return Markdown.ToHtml(markdown, builder.Build());
    }

    [Theory]
    [InlineData(":smile:", "😄")]
    [InlineData(":+1:", "👍")]
    [InlineData(":rocket:", "🚀")]
    [InlineData(":white_check_mark:", "✅")]
    [InlineData(":warning:", "⚠")]
    public void Github_shortcodes_render_as_unicode(string shortcode, string emoji) =>
        Assert.Contains(emoji, Render($"Done {shortcode} now"));

    [Theory]
    [InlineData("Happy :)")]
    [InlineData("Sad :(")]
    [InlineData(":not_a_real_shortcode:")]
    [InlineData("time 10:30:00")]
    public void Smileys_unknown_codes_and_times_are_unchanged(string text) =>
        Assert.Equal($"<p>{text}</p>\n", Render(text));

    [Fact]
    public void Shortcodes_in_code_are_unchanged() =>
        Assert.Equal("<p><code>:smile:</code></p>\n", Render("`:smile:`"));
}

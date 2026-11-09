using Markdig;

namespace MarkdownEditor.Plugin.Alerts.Tests;

public class AlertsPluginTests
{
    private static string Render(string markdown)
    {
        var builder = new MarkdownPipelineBuilder();
        new AlertsPlugin().ConfigurePipeline(builder);
        return Markdown.ToHtml(markdown, builder.Build());
    }

    [Theory]
    [InlineData("NOTE", "note", "Note")]
    [InlineData("TIP", "tip", "Tip")]
    [InlineData("IMPORTANT", "important", "Important")]
    [InlineData("WARNING", "warning", "Warning")]
    [InlineData("CAUTION", "caution", "Caution")]
    [InlineData("note", "note", "Note")]
    public void GitHub_alert_kinds_render_with_title_and_icon(string kind, string cssKind, string title)
    {
        var html = Render($"> [!{kind}]\n> Body text.\n");

        Assert.StartsWith($"<div class=\"markdown-alert markdown-alert-{cssKind}\">", html);
        Assert.Contains("<svg", html);
        Assert.Contains($"</svg>{title}</p>", html);
        Assert.Contains("<p>Body text.</p>", html);
    }

    [Theory]
    [InlineData("> [!foo]\n> x\n")]
    [InlineData("> [!NOTEX]\n> x\n")]
    [InlineData("> just a quote\n")]
    public void Other_blockquotes_stay_blockquotes(string markdown)
    {
        var html = Render(markdown);
        Assert.StartsWith("<blockquote>", html);
        Assert.DoesNotContain("markdown-alert", html);
    }

    [Fact]
    public void Declared_stylesheet_exists() =>
        Assert.True(File.Exists(Path.Combine(AppContext.BaseDirectory, AlertsPlugin.StylesheetPath)));
}

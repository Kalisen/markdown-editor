using System.Text.Json;
using MarkdownEditor.Core.Rendering;

namespace MarkdownEditor.Core.Tests.Rendering;

public class PreviewMessagesTests
{
    [Fact]
    public void Render_message_carries_html()
    {
        using var json = JsonDocument.Parse(PreviewMessages.Render("<p>a</p>"));
        Assert.Equal(PreviewMessages.RenderType, json.RootElement.GetProperty("type").GetString());
        Assert.Equal("<p>a</p>", json.RootElement.GetProperty("html").GetString());
    }

    [Fact]
    public void Parses_ready_and_open_link_messages()
    {
        Assert.Equal(new PreviewInboundMessage(PreviewInboundKind.Ready), PreviewMessages.TryParse("""{"type":"ready"}"""));
        Assert.Equal(new PreviewInboundMessage(PreviewInboundKind.OpenLink, "a.md"),
            PreviewMessages.TryParse("""{"type":"open-link","href":"a.md"}"""));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("not json")]
    [InlineData("\"ready\"")]
    [InlineData("""{"type":1}""")]
    [InlineData("""{"type":"other"}""")]
    [InlineData("""{"type":"open-link"}""")]
    [InlineData("""{"type":"open-link","href":{}}""")]
    public void Malformed_or_unknown_messages_are_ignored(string? json) =>
        Assert.Null(PreviewMessages.TryParse(json));

    [Theory]
    [InlineData(0.5, 0.5)]
    [InlineData(-1, 0)]
    [InlineData(2, 1)]
    public void Scroll_ratio_is_clamped(double ratio, double expected)
    {
        using var json = JsonDocument.Parse(PreviewMessages.Scroll(ratio));
        Assert.Equal(expected, json.RootElement.GetProperty("ratio").GetDouble());
    }
}

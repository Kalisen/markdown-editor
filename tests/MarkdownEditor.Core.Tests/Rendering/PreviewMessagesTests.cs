using System.Text.Json;
using MarkdownEditor.Core.Rendering;

namespace MarkdownEditor.Core.Tests.Rendering;

public class PreviewMessagesTests
{
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
    [InlineData(12.5, 0.5, 12.5, 0.5)]
    [InlineData(-1, 2, 0, 1)]
    public void Scroll_to_line_is_clamped(double line, double tail, double expectedLine, double expectedTail)
    {
        using var json = JsonDocument.Parse(PreviewMessages.ScrollToLine(new ScrollPosition(line, tail)));
        Assert.Equal(PreviewMessages.ScrollToLineType, json.RootElement.GetProperty("type").GetString());
        Assert.Equal(expectedLine, json.RootElement.GetProperty("line").GetDouble());
        Assert.Equal(expectedTail, json.RootElement.GetProperty("tail").GetDouble());
    }

    [Theory]
    [InlineData("""{"type":"scrolled","line":4.25,"tail":0.5}""", 0.5)]
    [InlineData("""{"type":"scrolled","line":4.25}""", 0)]
    [InlineData("""{"type":"scrolled","line":4.25,"tail":3}""", 1)]
    public void Parses_scrolled_message(string json, double tail) =>
        Assert.Equal(new PreviewInboundMessage(PreviewInboundKind.Scrolled, Position: new ScrollPosition(4.25, tail)),
            PreviewMessages.TryParse(json));

    [Theory]
    [InlineData("""{"type":"scrolled"}""")]
    [InlineData("""{"type":"scrolled","line":"4"}""")]
    [InlineData("""{"type":"scrolled","line":-1}""")]
    public void Malformed_scrolled_messages_are_ignored(string json) =>
        Assert.Null(PreviewMessages.TryParse(json));
}

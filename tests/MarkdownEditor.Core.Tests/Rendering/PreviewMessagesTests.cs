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
    [InlineData(12.5, 12.5)]
    [InlineData(-1, 0)]
    public void Scroll_to_line_is_not_negative(double line, double expected)
    {
        using var json = JsonDocument.Parse(PreviewMessages.ScrollToLine(line));
        Assert.Equal(PreviewMessages.ScrollToLineType, json.RootElement.GetProperty("type").GetString());
        Assert.Equal(expected, json.RootElement.GetProperty("line").GetDouble());
    }

    [Fact]
    public void Parses_scrolled_message() =>
        Assert.Equal(new PreviewInboundMessage(PreviewInboundKind.Scrolled, Line: 4.25),
            PreviewMessages.TryParse("""{"type":"scrolled","line":4.25}"""));

    [Theory]
    [InlineData("""{"type":"scrolled"}""")]
    [InlineData("""{"type":"scrolled","line":"4"}""")]
    [InlineData("""{"type":"scrolled","line":-1}""")]
    public void Malformed_scrolled_messages_are_ignored(string json) =>
        Assert.Null(PreviewMessages.TryParse(json));
}

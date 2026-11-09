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

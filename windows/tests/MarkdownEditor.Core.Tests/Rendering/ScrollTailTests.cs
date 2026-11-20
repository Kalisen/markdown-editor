using MarkdownEditor.Core.Rendering;

namespace MarkdownEditor.Core.Tests.Rendering;

public class ScrollTailTests
{
    // Scroll range [0, 1000] with a 300 px viewport: the tail is [700, 1000].
    [Theory]
    [InlineData(500, 0)]
    [InlineData(700, 0)]
    [InlineData(850, 0.5)]
    [InlineData(1000, 1)]
    public void Progress_through_the_last_viewport(double offset, double expected) =>
        Assert.Equal(expected, ScrollTail.Progress(offset, 1000, 300));

    [Fact]
    public void Content_shorter_than_two_viewports_blends_over_the_whole_range() =>
        Assert.Equal(0.5, ScrollTail.Progress(100, 200, 300));

    [Fact]
    public void Nothing_to_scroll_has_no_tail() =>
        Assert.Equal(0, ScrollTail.Progress(0, 0, 300));

    [Theory]
    [InlineData(0, 400)]       // line-matched position, untouched
    [InlineData(0.5, 1200)]    // halfway to the end
    [InlineData(1, 2000)]      // the driver reached its end: so does the follower
    public void Blend_moves_the_follower_toward_its_end(double tail, double expected) =>
        Assert.Equal(expected, ScrollTail.Blend(400, 2000, tail));
}

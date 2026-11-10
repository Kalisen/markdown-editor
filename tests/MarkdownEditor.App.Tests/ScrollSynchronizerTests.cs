using MarkdownEditor.App.Scrolling;
using MarkdownEditor.Core.Rendering;

namespace MarkdownEditor.App.Tests;

public class ScrollSynchronizerTests
{
    private readonly List<ScrollPosition> _preview = [];
    private readonly List<ScrollPosition> _editor = [];
    private readonly ScrollSynchronizer _sync;

    public ScrollSynchronizerTests() => _sync = new ScrollSynchronizer(_preview.Add, _editor.Add);

    [Fact]
    public void Editor_drives_by_default()
    {
        _sync.OnEditorScrolled(new(3.5, 0.25));

        Assert.Equal([new ScrollPosition(3.5, 0.25)], _preview);
    }

    [Fact]
    public void Preview_scroll_moves_the_editor_without_echoing_back()
    {
        _sync.OnPreviewScrolled(new(7.25));
        _sync.OnEditorScrolled(new(7.25)); // the editor following

        Assert.Equal([new ScrollPosition(7.25)], _editor);
        Assert.Empty(_preview);
        Assert.Equal(ScrollDriver.Preview, _sync.Driver);
    }

    [Fact]
    public void Editor_input_takes_the_lead_back()
    {
        _sync.OnPreviewScrolled(new(7));
        _sync.OnEditorInput();
        _sync.OnEditorScrolled(new(9));

        Assert.Equal([new ScrollPosition(9)], _preview);
    }

    [Theory]
    [InlineData(150, 100, 200, 0.5)]
    [InlineData(100, 100, 100, 0)] // empty span
    [InlineData(250, 100, 200, 1)]
    public void Fraction_of_a_line_span(double offset, double top, double bottom, double expected) =>
        Assert.Equal(expected, EditorLineGeometry.Fraction(offset, top, bottom));
}

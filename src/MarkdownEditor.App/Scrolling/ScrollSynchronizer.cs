using MarkdownEditor.Core.Rendering;

namespace MarkdownEditor.App.Scrolling;

/// <summary>The panel whose scrolling the other panel follows.</summary>
internal enum ScrollDriver
{
    Editor,
    Preview,
}

/// <summary>
/// Keeps the editor and the preview showing the same source line at their top. The panel that last received
/// user input drives; scrolls of the following panel (caused by the synchronization itself) are not echoed back.
/// </summary>
internal sealed class ScrollSynchronizer(Action<ScrollPosition> scrollPreview, Action<ScrollPosition> scrollEditor)
{
    public ScrollDriver Driver { get; private set; } = ScrollDriver.Editor;

    /// <summary>User input (wheel, keys, mouse, touch) targeted the editor.</summary>
    public void OnEditorInput() => Driver = ScrollDriver.Editor;

    public void OnEditorScrolled(ScrollPosition position)
    {
        if (Driver == ScrollDriver.Editor) scrollPreview(position);
    }

    /// <summary>The preview only reports scrolls caused by user input in it, so it becomes the driver.</summary>
    public void OnPreviewScrolled(ScrollPosition position)
    {
        Driver = ScrollDriver.Preview;
        scrollEditor(position);
    }
}

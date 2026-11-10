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
/// Positions are fractional 0-based source lines.
/// </summary>
internal sealed class ScrollSynchronizer(Action<double> scrollPreview, Action<double> scrollEditor)
{
    public ScrollDriver Driver { get; private set; } = ScrollDriver.Editor;

    /// <summary>User input (wheel, keys, mouse, touch) targeted the editor.</summary>
    public void OnEditorInput() => Driver = ScrollDriver.Editor;

    public void OnEditorScrolled(double topLine)
    {
        if (Driver == ScrollDriver.Editor) scrollPreview(topLine);
    }

    /// <summary>The preview only reports scrolls caused by user input in it, so it becomes the driver.</summary>
    public void OnPreviewScrolled(double topLine)
    {
        Driver = ScrollDriver.Preview;
        scrollEditor(topLine);
    }
}

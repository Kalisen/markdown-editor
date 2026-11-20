import MarkdownEditorCore

/// The panel whose scrolling the other panel follows.
enum ScrollDriver {
    case editor
    case preview
}

/// Keeps the editor and the preview showing the same source line at their top. The panel that last received
/// user input drives; scrolls of the following panel (caused by the synchronization itself) are not echoed back.
final class ScrollSynchronizer {
    private let scrollPreview: (ScrollPosition) -> Void
    private let scrollEditor: (ScrollPosition) -> Void

    private(set) var driver = ScrollDriver.editor

    init(scrollPreview: @escaping (ScrollPosition) -> Void, scrollEditor: @escaping (ScrollPosition) -> Void) {
        self.scrollPreview = scrollPreview
        self.scrollEditor = scrollEditor
    }

    /// User input (wheel, keys, mouse) targeted the editor.
    func editorReceivedInput() {
        driver = .editor
    }

    func editorScrolled(to position: ScrollPosition) {
        if driver == .editor { scrollPreview(position) }
    }

    /// The preview only reports scrolls caused by user input in it, so it becomes the driver.
    func previewScrolled(to position: ScrollPosition) {
        driver = .preview
        scrollEditor(position)
    }
}

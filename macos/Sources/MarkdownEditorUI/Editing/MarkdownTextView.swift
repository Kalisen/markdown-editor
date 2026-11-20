import AppKit

/// The Markdown source editor: plain text, monospaced, word-wrapped, with source highlighting of the
/// visible lines. Typing substitutions (smart quotes, dashes, text replacement) are off: they alter Markdown.
final class MarkdownTextView: NSTextView {
    static let fontSize: CGFloat = 14
    static let undoLimit = 2000
    /// Lines highlighted beyond the visible ones, so small scrolls show highlighted text at once.
    private static let highlightMargin = 60

    let baseFont = NSFont.monospacedSystemFont(ofSize: MarkdownTextView.fontSize, weight: .regular)

    /// Called for wheel, key and mouse input targeting the editor.
    var onUserInput: (() -> Void)?
    /// Called with the files dropped on the editor.
    var onFilesDropped: (([URL]) -> Void)?

    private(set) var lineIndex = LineIndex()
    private var highlightScheduled = false

    static func make() -> MarkdownTextView {
        let textView = MarkdownTextView(usingTextLayoutManager: false)
        textView.configure()
        return textView
    }

    private func configure() {
        isRichText = false
        importsGraphics = false
        allowsUndo = true
        usesFindBar = true
        isIncrementalSearchingEnabled = true
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isAutomaticDataDetectionEnabled = false
        smartInsertDeleteEnabled = false
        font = baseFont
        textColor = .labelColor
        backgroundColor = .textBackgroundColor
        typingAttributes = baseAttributes
        textContainerInset = NSSize(width: 4, height: 6)
        isVerticallyResizable = true
        isHorizontallyResizable = false
        autoresizingMask = [.width]
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textContainer?.widthTracksTextView = true
        undoManager?.levelsOfUndo = Self.undoLimit
    }

    private var baseAttributes: [NSAttributedString.Key: Any] {
        [.font: baseFont, .foregroundColor: NSColor.labelColor]
    }

    // MARK: Text

    /// Replaces the whole text (a document was loaded): the undo history does not apply to it.
    func load(_ text: String) {
        string = text
        undoManager?.removeAllActions()
        textChanged()
    }

    override func didChangeText() {
        super.didChangeText()
        textChanged()
    }

    private func textChanged() {
        lineIndex = LineIndex(string as NSString)
        undoManager?.levelsOfUndo = Self.undoLimit
        scheduleHighlight()
    }

    // MARK: Highlighting

    /// Highlights the visible lines on the next pass of the run loop (several requests are merged).
    func scheduleHighlight() {
        guard !highlightScheduled else { return }
        highlightScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.highlightScheduled = false
            self?.highlightVisibleLines()
        }
    }

    private func highlightVisibleLines() {
        // Attributes are left alone while an input method composes text.
        guard !hasMarkedText(), let layoutManager, let textContainer, let textStorage else { return }
        let text = string as NSString
        guard text.length > 0 else { return }
        let glyphs = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let characters = layoutManager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
        let firstLine = max(0, lineIndex.line(at: characters.location) - Self.highlightMargin)
        let lastLine = min(lineIndex.lineCount - 1, lineIndex.line(at: NSMaxRange(characters)) + Self.highlightMargin)
        let start = lineIndex.start(ofLine: firstLine)
        let range = NSRange(location: start, length: NSMaxRange(lineIndex.range(ofLine: lastLine, textLength: text.length)) - start)

        textStorage.beginEditing()
        textStorage.setAttributes(baseAttributes, range: range)
        for span in MarkdownSyntaxHighlighter.spans(forLines: firstLine..<(lastLine + 1), of: text, lineIndex: lineIndex) {
            textStorage.addAttributes(span.style.attributes(baseFont: baseFont), range: span.range)
        }
        textStorage.endEditing()
    }

    // MARK: User input

    override func scrollWheel(with event: NSEvent) {
        onUserInput?()
        super.scrollWheel(with: event)
    }

    override func keyDown(with event: NSEvent) {
        onUserInput?()
        super.keyDown(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        onUserInput?()
        super.mouseDown(with: event)
    }

    // MARK: File drops

    private func droppedFiles(_ sender: NSDraggingInfo) -> [URL] {
        sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppedFiles(sender).isEmpty ? super.draggingEntered(sender) : .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppedFiles(sender).isEmpty ? super.draggingUpdated(sender) : .copy
    }

    /// A dropped file is opened instead of having its path inserted in the text.
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let files = droppedFiles(sender)
        guard !files.isEmpty else { return super.performDragOperation(sender) }
        onFilesDropped?(files)
        return true
    }
}

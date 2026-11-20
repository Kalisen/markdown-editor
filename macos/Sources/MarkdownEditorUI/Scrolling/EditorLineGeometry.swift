import AppKit
import MarkdownEditorCore

/// Converts between the editor's vertical scroll offset and `ScrollPosition`s.
struct EditorLineGeometry {
    let textView: NSTextView
    let scrollView: NSScrollView
    let lineIndex: LineIndex

    /// The text view lays out long documents progressively and grows as it goes; positions are only
    /// meaningful against the whole document, so its layout is completed first (a no-op once done).
    init(textView: NSTextView, scrollView: NSScrollView, lineIndex: LineIndex) {
        self.textView = textView
        self.scrollView = scrollView
        self.lineIndex = lineIndex
        if let layoutManager = textView.layoutManager, let container = textView.textContainer {
            layoutManager.ensureLayout(for: container)
        }
    }

    var position: ScrollPosition {
        ScrollPosition(line: topLine, tail: ScrollTail.progress(offset: offset, maxOffset: maxOffset, viewport: viewport))
    }

    /// The vertical offset following `position`: its line at the top, blended toward the end.
    func offset(for position: ScrollPosition) -> CGFloat {
        ScrollTail.blend(lineOffset: offset(ofLine: position.line), maxOffset: maxOffset, tail: position.tail)
    }

    private var offset: CGFloat { scrollView.contentView.bounds.minY }

    private var viewport: CGFloat { scrollView.contentView.bounds.height }

    /// The height of the laid-out text with its insets (the view's frame may not have caught up yet).
    private var documentHeight: CGFloat {
        guard let layoutManager = textView.layoutManager, let container = textView.textContainer else { return textView.frame.height }
        return max(textView.frame.height, layoutManager.usedRect(for: container).height + 2 * textView.textContainerInset.height)
    }

    private var maxOffset: CGFloat { max(0, documentHeight - viewport) }

    /// The fractional source line at the top of the view: a wrapped line counts as one line spanning its visual rows.
    private var topLine: Double {
        guard let layoutManager = textView.layoutManager, let container = textView.textContainer, textView.string.utf16.count > 0 else { return 0 }
        let point = NSPoint(x: 0, y: max(0, offset - textView.textContainerOrigin.y))
        let glyph = layoutManager.glyphIndex(for: point, in: container)
        let line = lineIndex.line(at: layoutManager.characterIndexForGlyph(at: glyph))
        return Double(line) + Self.fraction(of: offset, from: top(ofLine: line), to: top(ofLine: line + 1))
    }

    /// The vertical offset showing the given fractional source line at the top.
    private func offset(ofLine line: Double) -> CGFloat {
        let index = min(max(Int(line.rounded(.down)), 0), lineIndex.lineCount - 1)
        let top = top(ofLine: index)
        return top + min(max(line - Double(index), 0), 1) * (self.top(ofLine: index + 1) - top)
    }

    /// How far `offset` is into the span [top, bottom), from 0 to 1.
    static func fraction(of offset: Double, from top: Double, to bottom: Double) -> Double {
        bottom > top ? min(max((offset - top) / (bottom - top), 0), 1) : 0
    }

    /// The top of the source line in the document view; the document height past the last line.
    /// The first line starts at the very top: the inset above it belongs to it.
    private func top(ofLine line: Int) -> CGFloat {
        guard line > 0 else { return 0 }
        guard let layoutManager = textView.layoutManager, line < lineIndex.lineCount else { return documentHeight }
        let character = lineIndex.start(ofLine: line)
        let origin = textView.textContainerOrigin.y
        if character >= textView.string.utf16.count {
            // An empty last line has no glyph: it is the extra line fragment.
            let extra = layoutManager.extraLineFragmentRect
            return extra.isEmpty ? documentHeight : extra.minY + origin
        }
        let glyph = layoutManager.glyphIndexForCharacter(at: character)
        return layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil).minY + origin
    }
}

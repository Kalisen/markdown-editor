import AppKit

/// Shows the number of each source line beside the editor; a wrapped line has one number, on its first row.
final class LineNumberRulerView: NSRulerView {
    private static let padding: CGFloat = 6
    private static let minimumDigits = 3

    private weak var textView: MarkdownTextView?
    private let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)

    init(textView: MarkdownTextView, scrollView: NSScrollView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        clipsToBounds = true
        updateThickness()
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("LineNumberRulerView is created in code")
    }

    /// Widens the ruler when the line count gains a digit.
    func updateThickness() {
        let digits = max(Self.minimumDigits, String(textView?.lineIndex.lineCount ?? 1).count)
        let width = ("8" as NSString).size(withAttributes: [.font: font]).width
        let thickness = ceil(CGFloat(digits) * width + 2 * Self.padding)
        if thickness != ruleThickness { ruleThickness = thickness }
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView, let layoutManager = textView.layoutManager, let container = textView.textContainer else { return }
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.secondaryLabelColor]
        let lineIndex = textView.lineIndex
        let textLength = textView.string.utf16.count
        let visible = textView.visibleRect
        let originY = textView.textContainerOrigin.y - visible.minY

        func draw(_ number: Int, atY y: CGFloat, height: CGFloat) {
            let label = String(number) as NSString
            let size = label.size(withAttributes: attributes)
            label.draw(at: NSPoint(x: ruleThickness - Self.padding - size.width, y: y + (height - size.height) / 2), withAttributes: attributes)
        }

        if textLength > 0 {
            let glyphs = layoutManager.glyphRange(forBoundingRect: visible, in: container)
            let characters = layoutManager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
            let lastLine = lineIndex.line(at: NSMaxRange(characters))
            for line in lineIndex.line(at: characters.location)...lastLine {
                let start = lineIndex.start(ofLine: line)
                guard start < textLength else { break }
                let fragment = layoutManager.lineFragmentRect(forGlyphAt: layoutManager.glyphIndexForCharacter(at: start), effectiveRange: nil)
                draw(line + 1, atY: fragment.minY + originY, height: fragment.height)
            }
        }
        // The empty last line (after a final line ending, or in an empty document) has no glyph.
        let extra = layoutManager.extraLineFragmentRect
        if !extra.isEmpty { draw(lineIndex.lineCount, atY: extra.minY + originY, height: extra.height) }
    }
}

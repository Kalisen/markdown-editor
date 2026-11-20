import AppKit

/// Source highlighting categories of the editor (same rules and colours as the Windows app).
enum MarkdownSyntaxStyle: Equatable {
    case heading
    case emphasis
    case strong
    case code
    case link
    case quote
    case listMarker
}

/// Highlights Markdown source line by line: fenced code spans lines; headings and quotes take their whole
/// line; code spans, strong, emphasis and links are highlighted inside the remaining text.
enum MarkdownSyntaxHighlighter {
    struct Span: Equatable {
        let range: NSRange
        let style: MarkdownSyntaxStyle
    }

    private static func regex(_ pattern: String) -> NSRegularExpression {
        // The patterns are constants: an invalid one is a programming error.
        try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
    }

    private static let lineRules: [(NSRegularExpression, MarkdownSyntaxStyle)] = [
        (regex(#"^\s{0,3}#{1,6}(\s.*)?$"#), .heading),
        (regex(#"^\s{0,3}>.*$"#), .quote),
        (regex(#"^\s*([-+*]|\d{1,9}[.)])(?=\s)"#), .listMarker),
    ]
    private static let inlineRules: [(NSRegularExpression, MarkdownSyntaxStyle)] = [
        (regex(#"`[^`\n]+`"#), .code),
        (regex(#"(\*\*|__)[^\s*_](.*?[^\s])?\1"#), .strong),
        (regex(#"(\*|_)[^\s*_](.*?[^\s])?\1"#), .emphasis),
        (regex(#"!?\[[^\]\n]*\]\([^)\n]*\)"#), .link),
    ]

    /// The spans of the given lines. Lines before them are only scanned for code fences.
    static func spans(forLines lines: Range<Int>, of text: NSString, lineIndex: LineIndex) -> [Span] {
        var spans: [Span] = []
        var insideFence = false
        for line in 0..<min(lines.upperBound, lineIndex.lineCount) {
            let range = contentRange(ofLine: line, text: text, lineIndex: lineIndex)
            let isHighlighted = line >= lines.lowerBound
            if insideFence {
                if isHighlighted, range.length > 0 { spans.append(Span(range: range, style: .code)) }
                if isFence(range, of: text, closing: true) { insideFence = false }
            } else if isFence(range, of: text, closing: false) {
                insideFence = true
                if isHighlighted { spans.append(Span(range: range, style: .code)) }
            } else if isHighlighted {
                spans.append(contentsOf: self.spans(inLine: range, of: text))
            }
        }
        return spans
    }

    static func spans(in text: String) -> [Span] {
        let lineIndex = LineIndex(text as NSString)
        return spans(forLines: 0..<lineIndex.lineCount, of: text as NSString, lineIndex: lineIndex)
    }

    /// A line starting, after at most three blanks, with ``` or ~~~; a closing fence has nothing else but blanks.
    /// Checked without a regular expression: every line before the highlighted ones goes through it.
    private static func isFence(_ range: NSRange, of text: NSString, closing: Bool) -> Bool {
        func isBlank(_ character: unichar) -> Bool { character == 0x20 || character == 0x09 }
        var index = range.location
        let end = NSMaxRange(range)
        while index < end, index - range.location < 3, isBlank(text.character(at: index)) { index += 1 }
        guard index + 3 <= end else { return false }
        let marker = text.character(at: index)
        guard marker == 0x60 || marker == 0x7E, text.character(at: index + 1) == marker, text.character(at: index + 2) == marker else { return false }
        guard closing else { return true }
        index += 3
        while index < end {
            if !isBlank(text.character(at: index)) { return false }
            index += 1
        }
        return true
    }

    /// The leftmost match wins (the first rule when several match there), then matching resumes after it.
    private static func spans(inLine range: NSRange, of text: NSString) -> [Span] {
        var spans: [Span] = []
        var position = range.location
        let end = NSMaxRange(range)
        while position < end {
            let remaining = NSRange(location: position, length: end - position)
            var best: Span?
            for (rule, style) in lineRules + inlineRules {
                // Line rules are anchored at the start of the line.
                guard let match = rule.firstMatch(in: text as String, options: position == range.location ? [] : [.withoutAnchoringBounds], range: remaining),
                      match.range.length > 0, match.range.location < best?.range.location ?? Int.max else { continue }
                best = Span(range: match.range, style: style)
            }
            guard let best else { break }
            spans.append(best)
            position = NSMaxRange(best.range)
        }
        return spans
    }

    /// The line without its line ending.
    private static func contentRange(ofLine line: Int, text: NSString, lineIndex: LineIndex) -> NSRange {
        var range = lineIndex.range(ofLine: line, textLength: text.length)
        while range.length > 0, [0x0A, 0x0D].contains(text.character(at: NSMaxRange(range) - 1)) { range.length -= 1 }
        return range
    }
}

extension MarkdownSyntaxStyle {
    private static func color(_ hex: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    /// The attributes drawn over the editor's base font.
    func attributes(baseFont: NSFont) -> [NSAttributedString.Key: Any] {
        let manager = NSFontManager.shared
        switch self {
        case .heading: return [.foregroundColor: Self.color(0x3A7BD5), .font: manager.convert(baseFont, toHaveTrait: .boldFontMask)]
        case .emphasis: return [.font: manager.convert(baseFont, toHaveTrait: .italicFontMask)]
        case .strong: return [.font: manager.convert(baseFont, toHaveTrait: .boldFontMask)]
        case .code: return [.foregroundColor: Self.color(0xC2185B)]
        case .link: return [.foregroundColor: Self.color(0x2E8B57)]
        case .quote: return [.foregroundColor: Self.color(0x808080)]
        case .listMarker: return [.foregroundColor: Self.color(0xE07B00), .font: manager.convert(baseFont, toHaveTrait: .boldFontMask)]
        }
    }
}

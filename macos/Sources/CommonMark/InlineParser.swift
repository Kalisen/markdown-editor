/// A delimiter that wraps inline content, like `*` and `_`.
public struct EmphasisDelimiter {
    public let character: UInt8
    /// False for delimiters that, like `_`, cannot open or close inside a word.
    public let allowsIntraword: Bool
    /// Runs longer than this are literal text; nil for no limit.
    public let maximumRunLength: Int?
    /// True when an opening run only matches a closing run of the same length, both consumed whole
    /// (otherwise the `*` rules apply: one delimiter for emphasis, two for strong).
    public let matchesWholeRuns: Bool
    /// HTML tag for the number of delimiters consumed on each side.
    public let tagName: (_ count: Int) -> String

    public init(character: UInt8, allowsIntraword: Bool, maximumRunLength: Int? = nil, matchesWholeRuns: Bool = false,
                tagName: @escaping (Int) -> String) {
        self.character = character
        self.allowsIntraword = allowsIntraword
        self.maximumRunLength = maximumRunLength
        self.matchesWholeRuns = matchesWholeRuns
        self.tagName = tagName
    }

    static let core: [EmphasisDelimiter] = [
        EmphasisDelimiter(character: Byte.asterisk, allowsIntraword: true) { $0 == 1 ? "em" : "strong" },
        EmphasisDelimiter(character: Byte.underscore, allowsIntraword: false) { $0 == 1 ? "em" : "strong" },
    ]
}

/// An extra inline construct, tried before the CommonMark rules when the parser meets one of its trigger bytes.
public struct InlineStart {
    public let triggerCharacters: Set<UInt8>
    /// Parses at `parser.position`; on success appends nodes with `parser.append`, advances the position and returns true.
    public let tryParse: (_ parser: InlineParser) -> Bool

    public init(triggerCharacters: Set<UInt8>, tryParse: @escaping (InlineParser) -> Bool) {
        self.triggerCharacters = triggerCharacters
        self.tryParse = tryParse
    }
}

/// Parses the inline content of one leaf block (CommonMark delimiter-stack algorithm).
public final class InlineParser {
    private final class Delimiter {
        let rule: EmphasisDelimiter
        var count: Int
        let originalCount: Int
        let node: Text
        var previous: Delimiter?
        var next: Delimiter?
        let canOpen: Bool
        let canClose: Bool

        init(rule: EmphasisDelimiter, count: Int, node: Text, previous: Delimiter?, canOpen: Bool, canClose: Bool) {
            self.rule = rule
            self.count = count
            originalCount = count
            self.node = node
            self.previous = previous
            self.canOpen = canOpen
            self.canClose = canClose
        }
    }

    private final class Bracket {
        let node: Text
        let previous: Bracket?
        let previousDelimiter: Delimiter?
        /// Position right after the `[`.
        let index: Int
        let isImage: Bool
        var isActive = true
        var hasBracketAfter = false

        init(node: Text, previous: Bracket?, previousDelimiter: Delimiter?, index: Int, isImage: Bool) {
            self.node = node
            self.previous = previous
            self.previousDelimiter = previousDelimiter
            self.index = index
            self.isImage = isImage
        }
    }

    /// The text being parsed.
    public let subject: [UInt8]
    public var position = 0
    /// The leaf block whose content is parsed.
    public let block: Block
    public let document: Document

    private let container: Node
    private let pipeline: MarkdownPipeline
    private var delimiters: Delimiter?
    private var brackets: Bracket?

    init(subject: [UInt8], block: Block, container: Node, document: Document, pipeline: MarkdownPipeline) {
        self.subject = subject
        self.block = block
        self.container = container
        self.document = document
        self.pipeline = pipeline
    }

    /// Parses the raw content of `block` into inline children.
    static func parseContent(of block: Block, document: Document, pipeline: MarkdownPipeline) {
        var content = block.rawContent[...]
        while let first = content.first, Byte.isWhitespace(first) { content = content.dropFirst() }
        while let last = content.last, Byte.isWhitespace(last) { content = content.dropLast() }
        block.rawContent = []
        let parser = InlineParser(subject: Array(content), block: block, container: block, document: document, pipeline: pipeline)
        parser.run()
    }

    private func run() {
        while parseInline() {}
        processEmphasis(above: nil)
        mergeAdjacentText(in: container)
    }

    // MARK: Extension interface

    public func peek(_ ahead: Int = 0) -> UInt8? { subject.at(position + ahead) }

    public var isAtEnd: Bool { position >= subject.count }

    /// Appends a node at the current end of the inline content.
    public func append(_ node: Node) { container.appendChild(node) }

    /// The scalar before the current position (a line feed at the start of the content).
    public var scalarBefore: Unicode.Scalar { subject.scalar(before: position) }

    /// The scalar at `index` (a line feed past the end of the content).
    public func scalar(at index: Int) -> Unicode.Scalar { subject.scalar(at: index) }

    public func text(_ range: Range<Int>) -> String { subject.string(range) }

    // MARK: Dispatch

    private func parseInline() -> Bool {
        guard let byte = peek() else { return false }
        if pipeline.inlineTriggers[Int(byte)] {
            for start in pipeline.inlineStarts where start.triggerCharacters.contains(byte) {
                let before = position
                if start.tryParse(self) { return true }
                position = before
            }
        }
        var handled: Bool
        switch byte {
        case Byte.newline: handled = parseNewline()
        case Byte.backslash: handled = parseBackslash()
        case Byte.backtick: handled = parseBackticks()
        case Byte.openBracket: handled = parseOpenBracket()
        case Byte.bang: handled = parseBang()
        case Byte.closeBracket: handled = parseCloseBracket()
        case Byte.lessThan: handled = parseAutolink() || parseHTMLTag()
        case Byte.ampersand: handled = parseEntity()
        default:
            if let rule = pipeline.delimiterRules[Int(byte)] {
                handled = handleDelimiter(rule)
            } else {
                handled = parseString()
            }
        }
        if !handled {
            // A special byte with no special meaning here.
            position += 1
            append(Text(String(decoding: [byte], as: UTF8.self)))
        }
        return true
    }

    private func parseString() -> Bool {
        let start = position
        while let byte = peek(), !pipeline.specialBytes[Int(byte)] { position += 1 }
        guard position > start else { return false }
        append(Text(subject.string(start..<position)))
        return true
    }

    /// Two or more trailing spaces before the line ending make a hard break.
    private func parseNewline() -> Bool {
        position += 1
        if let last = container.lastChild as? Text, type(of: last) == Text.self, last.literal.hasSuffix(" ") {
            let isHardBreak = last.literal.hasSuffix("  ")
            while last.literal.hasSuffix(" ") { last.literal.removeLast() }
            append(isHardBreak ? LineBreak() : SoftBreak())
        } else {
            append(SoftBreak())
        }
        while peek() == Byte.space { position += 1 }
        return true
    }

    private func parseBackslash() -> Bool {
        position += 1
        if peek() == Byte.newline {
            position += 1
            append(LineBreak())
            while peek() == Byte.space { position += 1 }
        } else if let byte = peek(), Byte.isPunctuation(byte) {
            append(Text(String(decoding: [byte], as: UTF8.self)))
            position += 1
        } else {
            append(Text("\\"))
        }
        return true
    }

    private func parseBackticks() -> Bool {
        let start = position
        while peek() == Byte.backtick { position += 1 }
        let length = position - start
        let afterOpening = position
        var scan = position
        while scan < subject.count {
            guard subject[scan] == Byte.backtick else {
                scan += 1
                continue
            }
            let runStart = scan
            while subject.at(scan) == Byte.backtick { scan += 1 }
            guard scan - runStart == length else { continue }
            var content = Array(subject[afterOpening..<runStart])
            for index in content.indices where content[index] == Byte.newline { content[index] = Byte.space }
            // One space is stripped from each side unless the content is only spaces.
            if content.count >= 2, content.first == Byte.space, content.last == Byte.space, content.contains(where: { $0 != Byte.space }) {
                content = Array(content[1..<(content.count - 1)])
            }
            append(Code(content.string))
            position = scan
            return true
        }
        // No closing run of the same length: the backticks are literal.
        position = afterOpening
        append(Text(String(repeating: "`", count: length)))
        return true
    }

    private func parseEntity() -> Bool {
        guard let entity = HTMLEntities.scan(subject, at: position) else { return false }
        append(Text(entity.text))
        position = entity.end
        return true
    }

    // MARK: Autolinks and raw HTML

    private func parseAutolink() -> Bool {
        guard let end = subject[position...].firstIndex(of: Byte.greaterThan) else { return false }
        let inner = Array(subject[(position + 1)..<end])
        let isEmail = InlineSyntax.isEmailAddress(inner)
        guard isEmail || InlineSyntax.isAbsoluteURI(inner) else { return false }
        let text = inner.string
        let link = Link(destination: LinkDestination.normalize(isEmail ? "mailto:" + text : text), isAutolink: true)
        link.appendChild(Text(text))
        append(link)
        position = end + 1
        return true
    }

    private func parseHTMLTag() -> Bool {
        guard let end = HTMLTagScanner.scan(subject, at: position) else { return false }
        append(HTMLInline(subject.string(position..<end)))
        position = end
        return true
    }

    // MARK: Emphasis

    private func handleDelimiter(_ rule: EmphasisDelimiter) -> Bool {
        let start = position
        while peek() == rule.character { position += 1 }
        let count = position - start
        let node = Text(subject.string(start..<position))
        append(node)
        if let maximum = rule.maximumRunLength, count > maximum { return true }

        let before = subject.scalar(before: start)
        let after = subject.scalar(at: position)
        let afterIsWhitespace = UnicodeClass.isWhitespace(after)
        let afterIsPunctuation = UnicodeClass.isPunctuation(after)
        let beforeIsWhitespace = UnicodeClass.isWhitespace(before)
        let beforeIsPunctuation = UnicodeClass.isPunctuation(before)
        let leftFlanking = !afterIsWhitespace && (!afterIsPunctuation || beforeIsWhitespace || beforeIsPunctuation)
        let rightFlanking = !beforeIsWhitespace && (!beforeIsPunctuation || afterIsWhitespace || afterIsPunctuation)
        let canOpen = rule.allowsIntraword ? leftFlanking : leftFlanking && (!rightFlanking || beforeIsPunctuation)
        let canClose = rule.allowsIntraword ? rightFlanking : rightFlanking && (!leftFlanking || afterIsPunctuation)
        guard canOpen || canClose else { return true }

        let delimiter = Delimiter(rule: rule, count: count, node: node, previous: delimiters, canOpen: canOpen, canClose: canClose)
        delimiters?.next = delimiter
        delimiters = delimiter
        return true
    }

    private func remove(_ delimiter: Delimiter) {
        delimiter.previous?.next = delimiter.next
        if let next = delimiter.next {
            next.previous = delimiter.previous
        } else {
            delimiters = delimiter.previous
        }
    }

    /// Matches closing delimiter runs with opening ones above `bottom` in the stack, wrapping the nodes between them.
    private func processEmphasis(above bottom: Delimiter?) {
        // Lower bounds of opener searches, per kind of closer: nothing below can match that kind.
        var openersBottom: [Int: Delimiter?] = [:]

        var closer = delimiters
        while let current = closer, current.previous !== bottom { closer = current.previous }

        while let current = closer {
            guard current.canClose else {
                closer = current.next
                continue
            }
            let rule = current.rule
            let bucket = Int(rule.character) << 8
                | (rule.matchesWholeRuns ? min(current.originalCount, 15) << 2 : (current.originalCount % 3) << 2)
                | (current.canOpen ? 1 : 0)
            let searchBottom: Delimiter? = openersBottom[bucket] ?? bottom

            var opener = current.previous
            var found = false
            while let candidate = opener, candidate !== bottom, candidate !== searchBottom {
                if candidate.rule.character == rule.character, candidate.canOpen {
                    if rule.matchesWholeRuns {
                        found = candidate.count == current.count
                    } else {
                        // A run that can both open and close does not match when the lengths add up to a multiple of 3,
                        // unless both are multiples of 3.
                        let oddMatch = (current.canOpen || candidate.canClose) && current.originalCount % 3 != 0
                            && (candidate.originalCount + current.originalCount) % 3 == 0
                        found = !oddMatch
                    }
                    if found { break }
                }
                opener = candidate.previous
            }

            let oldCloser = current
            if found, let opener {
                let used = rule.matchesWholeRuns ? current.count : (current.count >= 2 && opener.count >= 2 ? 2 : 1)
                opener.count -= used
                current.count -= used
                opener.node.literal.removeLast(used)
                current.node.literal.removeLast(used)

                let emphasis = Emphasis(delimiter: rule.character, delimiterCount: used, tagName: rule.tagName(used))
                var node = opener.node.next
                while let inner = node, inner !== current.node {
                    node = inner.next
                    emphasis.appendChild(inner)
                }
                opener.node.insertAfter(emphasis)

                // Delimiters between the opener and the closer cannot match anymore.
                if opener.next !== current {
                    opener.next = current
                    current.previous = opener
                }
                if opener.count == 0 {
                    opener.node.unlink()
                    remove(opener)
                }
                if current.count == 0 {
                    current.node.unlink()
                    closer = current.next
                    remove(current)
                }
            } else {
                closer = current.next
                openersBottom[bucket] = .some(oldCloser.previous)
                // A closer that cannot open is of no use once no opener matches it.
                if !oldCloser.canOpen { remove(oldCloser) }
            }
        }

        while let top = delimiters, top !== bottom { remove(top) }
    }

    // MARK: Links and images

    private func parseOpenBracket() -> Bool {
        position += 1
        let node = Text("[")
        append(node)
        addBracket(node, index: position, isImage: false)
        return true
    }

    private func parseBang() -> Bool {
        position += 1
        guard peek() == Byte.openBracket else {
            append(Text("!"))
            return true
        }
        position += 1
        let node = Text("![")
        append(node)
        addBracket(node, index: position, isImage: true)
        return true
    }

    private func addBracket(_ node: Text, index: Int, isImage: Bool) {
        brackets?.hasBracketAfter = true
        brackets = Bracket(node: node, previous: brackets, previousDelimiter: delimiters, index: index, isImage: isImage)
    }

    private func parseCloseBracket() -> Bool {
        let closeIndex = position
        position += 1
        let afterClose = position

        guard let opener = brackets else {
            append(Text("]"))
            return true
        }
        guard opener.isActive else {
            append(Text("]"))
            brackets = opener.previous
            return true
        }

        var destination: String?
        var title: String?
        var matched = false

        // Inline link: (destination "title")
        if peek() == Byte.openParen {
            position += 1
            skipSpacesAndOneLineEnding()
            if let parsed = parseLinkDestination() {
                let afterDestination = position
                skipSpacesAndOneLineEnding()
                var parsedTitle: String?
                // A title must be separated from the destination by whitespace.
                if position > afterDestination, let found = parseLinkTitle() { parsedTitle = found }
                skipSpacesAndOneLineEnding()
                if peek() == Byte.closeParen {
                    position += 1
                    destination = parsed
                    title = parsedTitle
                    matched = true
                }
            }
            if !matched { position = afterClose }
        }

        // Reference link: [label], [] or shortcut.
        if !matched {
            let beforeLabel = position
            let labelLength = InlineSyntax.linkLabelLength(subject, at: position)
            var label: [UInt8]?
            if labelLength > 2 {
                label = Array(subject[beforeLabel..<(beforeLabel + labelLength)])
            } else if !opener.hasBracketAfter {
                // An empty or missing second label means the link text is the label; it cannot contain brackets.
                label = Array(subject[(opener.index - 1)...closeIndex])
            }
            position = labelLength == 0 ? afterClose : beforeLabel + labelLength
            if let label, let reference = document.references[InlineSyntax.normalizeLabel(label)] {
                destination = reference.destination
                title = reference.title
                matched = true
            }
        }

        guard matched, let destination else {
            brackets = opener.previous
            position = afterClose
            append(Text("]"))
            return true
        }

        let node: Node = opener.isImage ? Image(destination: destination, title: title) : Link(destination: destination, title: title)
        var inner = opener.node.next
        while let current = inner {
            inner = current.next
            node.appendChild(current)
        }
        append(node)
        processEmphasis(above: opener.previousDelimiter)
        brackets = opener.previous
        opener.node.unlink()

        // Links cannot contain links: earlier link openers are deactivated.
        if !opener.isImage {
            var earlier = brackets
            while let bracket = earlier {
                if !bracket.isImage { bracket.isActive = false }
                earlier = bracket.previous
            }
        }
        return true
    }

    private func skipSpacesAndOneLineEnding() {
        while Byte.isSpaceOrTab(peek()) { position += 1 }
        if peek() == Byte.newline {
            position += 1
            while Byte.isSpaceOrTab(peek()) { position += 1 }
        }
    }

    /// - Returns: the normalized destination, or nil when there is none at the current position.
    private func parseLinkDestination() -> String? {
        guard let end = InlineSyntax.linkDestinationEnd(subject, at: position) else { return nil }
        let isBracketed = peek() == Byte.lessThan
        let raw = isBracketed ? Array(subject[(position + 1)..<(end - 1)]) : Array(subject[position..<end])
        position = end
        return LinkDestination.normalize(Unescaping.unescape(raw))
    }

    private func parseLinkTitle() -> String? {
        guard let end = InlineSyntax.linkTitleEnd(subject, at: position) else { return nil }
        let title = Unescaping.unescape(Array(subject[(position + 1)..<(end - 1)]))
        position = end
        return title
    }

    // MARK: Link reference definitions

    /// Parses one link reference definition at the start of `content` and records it (the first definition of a label wins).
    /// - Returns: the number of bytes consumed, or 0 when the content does not start with a definition.
    static func parseReferenceDefinition(_ content: [UInt8], into document: Document) -> Int {
        let labelLength = InlineSyntax.linkLabelLength(content, at: 0)
        guard labelLength > 0, content.at(labelLength) == Byte.colon else { return 0 }
        var position = labelLength + 1

        func skipSpacesAndOneLineEnding() {
            while Byte.isSpaceOrTab(content.at(position)) { position += 1 }
            if content.at(position) == Byte.newline {
                position += 1
                while Byte.isSpaceOrTab(content.at(position)) { position += 1 }
            }
        }
        /// Consumes trailing spaces and the line ending; false when something else follows on the line.
        func consumeLineEnd() -> Bool {
            var end = position
            while Byte.isSpaceOrTab(content.at(end)) { end += 1 }
            if end == content.count {
                position = end
                return true
            }
            guard content[end] == Byte.newline else { return false }
            position = end + 1
            return true
        }

        skipSpacesAndOneLineEnding()
        guard let destinationEnd = InlineSyntax.linkDestinationEnd(content, at: position) else { return 0 }
        let isBracketed = content.at(position) == Byte.lessThan
        let rawDestination = isBracketed ? Array(content[(position + 1)..<(destinationEnd - 1)]) : Array(content[position..<destinationEnd])
        position = destinationEnd

        let beforeTitle = position
        skipSpacesAndOneLineEnding()
        var title: String?
        if position > beforeTitle, let titleEnd = InlineSyntax.linkTitleEnd(content, at: position) {
            title = Unescaping.unescape(Array(content[(position + 1)..<(titleEnd - 1)]))
            position = titleEnd
        } else {
            position = beforeTitle
        }

        if !consumeLineEnd() {
            // The title is not at a line end: the definition may still be valid without it.
            guard title != nil else { return 0 }
            title = nil
            position = beforeTitle
            guard consumeLineEnd() else { return 0 }
        }

        let label = InlineSyntax.normalizeLabel(Array(content[0..<labelLength]))
        guard !label.isEmpty else { return 0 }
        if document.references[label] == nil {
            document.references[label] = LinkReference(
                destination: LinkDestination.normalize(Unescaping.unescape(rawDestination)), title: title)
        }
        return position
    }

    // MARK: Text consolidation

    /// Merges runs of adjacent plain text nodes, so document processors see whole words and URLs.
    private func mergeAdjacentText(in parent: Node) {
        var node = parent.firstChild
        while let current = node {
            if let text = current as? Text, type(of: text) == Text.self {
                while let following = text.next as? Text, type(of: following) == Text.self {
                    text.literal += following.literal
                    following.unlink()
                }
                if text.literal.isEmpty {
                    node = text.next
                    text.unlink()
                    continue
                }
            } else if current.firstChild != nil {
                mergeAdjacentText(in: current)
            }
            node = current.next
        }
    }
}

/// Character-level syntax of inline constructs.
enum InlineSyntax {
    /// Length of the link label (brackets included) at `start`, or 0. A label holds at most 999 characters
    /// and no unescaped bracket.
    static func linkLabelLength(_ bytes: [UInt8], at start: Int) -> Int {
        guard bytes.at(start) == Byte.openBracket else { return 0 }
        var position = start + 1
        while let byte = bytes.at(position), position - start <= 1000 {
            if byte == Byte.closeBracket { return position - start + 1 }
            if byte == Byte.openBracket { return 0 }
            position += byte == Byte.backslash && position + 1 < bytes.count ? 2 : 1
        }
        return 0
    }

    /// Labels match case-insensitively with inner whitespace collapsed.
    static func normalizeLabel(_ label: [UInt8]) -> String {
        let inner = label.dropFirst().dropLast()
        var collapsed: [UInt8] = []
        collapsed.reserveCapacity(inner.count)
        var pendingSpace = false
        for byte in inner {
            if Byte.isWhitespace(byte) {
                pendingSpace = !collapsed.isEmpty
            } else {
                if pendingSpace { collapsed.append(Byte.space) }
                pendingSpace = false
                collapsed.append(byte)
            }
        }
        // Full case folding: lowercased then uppercased, so that e.g. "ẞ" matches "SS".
        return collapsed.string.lowercased().uppercased()
    }

    /// Index after the link destination at `start`, or nil. Either `<…>` without line endings,
    /// or a run without spaces or control characters and with balanced parentheses.
    static func linkDestinationEnd(_ bytes: [UInt8], at start: Int) -> Int? {
        if bytes.at(start) == Byte.lessThan {
            var position = start + 1
            while let byte = bytes.at(position) {
                if byte == Byte.greaterThan { return position + 1 }
                if byte == Byte.newline || byte == Byte.lessThan { return nil }
                position += byte == Byte.backslash && position + 1 < bytes.count ? 2 : 1
            }
            return nil
        }
        var position = start
        var openParens = 0
        while let byte = bytes.at(position) {
            if byte == Byte.backslash, let following = bytes.at(position + 1), Byte.isPunctuation(following) {
                position += 2
            } else if byte == Byte.openParen {
                openParens += 1
                position += 1
            } else if byte == Byte.closeParen {
                if openParens < 1 { break }
                openParens -= 1
                position += 1
            } else if byte <= Byte.space || byte == 0x7F {
                break
            } else {
                position += 1
            }
        }
        if position == start, bytes.at(position) != Byte.closeParen { return nil }
        return openParens == 0 ? position : nil
    }

    /// Index after the link title at `start` (`"…"`, `'…'` or `(…)`), or nil.
    static func linkTitleEnd(_ bytes: [UInt8], at start: Int) -> Int? {
        guard let opening = bytes.at(start) else { return nil }
        let closing: UInt8
        switch opening {
        case Byte.doubleQuote, Byte.singleQuote: closing = opening
        case Byte.openParen: closing = Byte.closeParen
        default: return nil
        }
        var position = start + 1
        while let byte = bytes.at(position) {
            if byte == closing { return position + 1 }
            if opening == Byte.openParen, byte == Byte.openParen { return nil }
            position += byte == Byte.backslash && position + 1 < bytes.count ? 2 : 1
        }
        return nil
    }

    /// A scheme of 2 to 32 characters, a colon, then anything but spaces, control characters, `<` and `>`.
    static func isAbsoluteURI(_ bytes: [UInt8]) -> Bool {
        guard let first = bytes.first, Byte.isLetter(first) else { return false }
        var position = 1
        while let byte = bytes.at(position), Byte.isAlphanumeric(byte) || byte == Byte.plus || byte == Byte.dot || byte == Byte.dash {
            position += 1
        }
        guard position >= 2, position <= 32, bytes.at(position) == Byte.colon else { return false }
        return bytes[(position + 1)...].allSatisfy { $0 > Byte.space && $0 != Byte.lessThan && $0 != Byte.greaterThan && $0 != 0x7F }
    }

    private static let emailLocalExtras = Set("-.!#$%&'*+/=?^_`{|}~".utf8)

    static func isEmailAddress(_ bytes: [UInt8]) -> Bool {
        guard let at = bytes.firstIndex(of: Byte.at), at > 0 else { return false }
        guard bytes[..<at].allSatisfy({ Byte.isAlphanumeric($0) || emailLocalExtras.contains($0) }) else { return false }
        let labels = bytes[(at + 1)...].split(separator: Byte.dot, omittingEmptySubsequences: false)
        guard !labels.isEmpty else { return false }
        return labels.allSatisfy { label in
            guard let first = label.first, let last = label.last, label.count <= 63,
                  Byte.isAlphanumeric(first), Byte.isAlphanumeric(last) else { return false }
            return label.allSatisfy { Byte.isAlphanumeric($0) || $0 == Byte.dash }
        }
    }
}

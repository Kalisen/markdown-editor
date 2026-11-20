extension BlockParser {
    /// The CommonMark block starts, in the order they are tried.
    static let coreStarts: [BlockStart] = [
        BlockStart(openingCharacters: nil, tryStart: startBlockQuote),
        BlockStart(openingCharacters: nil, tryStart: startATXHeading),
        BlockStart(openingCharacters: nil, tryStart: startFencedCode),
        BlockStart(openingCharacters: nil, tryStart: startHTMLBlock),
        BlockStart(openingCharacters: nil, tryStart: startSetextHeading),
        BlockStart(openingCharacters: nil, tryStart: startThematicBreak),
        BlockStart(openingCharacters: nil, tryStart: startListItem),
        BlockStart(openingCharacters: nil, tryStart: startIndentedCode),
    ]

    private static func startBlockQuote(_ parser: BlockParser, _ container: Block) -> BlockStartResult {
        guard !parser.isIndented, parser.line.at(parser.nextNonspace) == Byte.greaterThan else { return .none }
        parser.advanceNextNonspace()
        parser.advanceOffset(1, columns: false)
        if Byte.isSpaceOrTab(parser.line.at(parser.offset)) { parser.advanceOffset(1, columns: true) }
        parser.closeUnmatchedBlocks()
        parser.addChild(BlockQuote())
        return .container
    }

    private static func startATXHeading(_ parser: BlockParser, _ container: Block) -> BlockStartResult {
        guard !parser.isIndented, parser.line.at(parser.nextNonspace) == Byte.hash else { return .none }
        let line = parser.line
        var end = parser.nextNonspace
        while line.at(end) == Byte.hash { end += 1 }
        let level = end - parser.nextNonspace
        guard level <= 6, end == line.count || Byte.isSpaceOrTab(line[end]) else { return .none }

        parser.advanceNextNonspace()
        parser.advanceOffset(level, columns: false)
        parser.closeUnmatchedBlocks()
        let heading = parser.addChild(Heading(level: level))

        // Remove the closing sequence: trailing #s preceded by a space or tab (or making up the whole content).
        var content = Array(line[parser.offset...])
        var contentEnd = content.count
        while contentEnd > 0, Byte.isSpaceOrTab(content[contentEnd - 1]) { contentEnd -= 1 }
        var hashesStart = contentEnd
        while hashesStart > 0, content[hashesStart - 1] == Byte.hash { hashesStart -= 1 }
        if hashesStart < contentEnd, hashesStart == 0 || Byte.isSpaceOrTab(content[hashesStart - 1]) {
            content.removeSubrange(hashesStart...)
        }
        heading.rawContent = content
        parser.advanceToEndOfLine()
        return .leaf
    }

    private static func startFencedCode(_ parser: BlockParser, _ container: Block) -> BlockStartResult {
        guard !parser.isIndented, let fence = parser.line.at(parser.nextNonspace),
              fence == Byte.backtick || fence == Byte.tilde else { return .none }
        let line = parser.line
        var end = parser.nextNonspace
        while line.at(end) == fence { end += 1 }
        let length = end - parser.nextNonspace
        guard length >= 3 else { return .none }
        // The info string of a backtick fence cannot contain backticks.
        if fence == Byte.backtick, line[end...].contains(Byte.backtick) { return .none }

        parser.closeUnmatchedBlocks()
        let code = parser.addChild(CodeBlock())
        code.isFenced = true
        code.fenceLength = length
        code.fenceCharacter = fence
        code.fenceOffset = parser.indent
        parser.advanceNextNonspace()
        parser.advanceOffset(length, columns: false)
        return .leaf
    }

    private static func startHTMLBlock(_ parser: BlockParser, _ container: Block) -> BlockStartResult {
        guard !parser.isIndented, parser.line.at(parser.nextNonspace) == Byte.lessThan else { return .none }
        // A complete tag (condition 7) cannot interrupt a paragraph, not even as a lazy continuation.
        let mayBeLazy = !parser.allBlocksClosed && !parser.isBlank && parser.tip is Paragraph
        let canUseCondition7 = !(container is Paragraph) && !mayBeLazy
        guard let condition = HTMLBlockSyntax.startCondition(parser.line, from: parser.nextNonspace),
              condition < 7 || canUseCondition7 else { return .none }
        parser.closeUnmatchedBlocks()
        // The offset is not advanced: leading spaces are part of the HTML block.
        parser.addChild(HTMLBlock(condition: condition))
        return .leaf
    }

    private static func startSetextHeading(_ parser: BlockParser, _ container: Block) -> BlockStartResult {
        guard !parser.isIndented, let paragraph = container as? Paragraph,
              let marker = parser.line.at(parser.nextNonspace), marker == Byte.equals || marker == Byte.dash else { return .none }
        var end = parser.nextNonspace
        while parser.line.at(end) == marker { end += 1 }
        guard parser.line.isBlank(from: end) else { return .none }

        parser.closeUnmatchedBlocks()
        _ = parser.consumeReferenceDefinitions(from: paragraph)
        guard !paragraph.rawContent.isEmpty else { return .none }

        let heading = Heading(level: marker == Byte.equals ? 1 : 2)
        heading.startLine = paragraph.startLine
        heading.endLine = parser.lineNumber
        heading.rawContent = paragraph.rawContent
        paragraph.replace(with: heading)
        parser.tip = heading
        parser.advanceToEndOfLine()
        return .leaf
    }

    private static func startThematicBreak(_ parser: BlockParser, _ container: Block) -> BlockStartResult {
        guard !parser.isIndented, BlockSyntax.isThematicBreak(parser.line, from: parser.nextNonspace) else { return .none }
        parser.closeUnmatchedBlocks()
        parser.addChild(ThematicBreak())
        parser.advanceToEndOfLine()
        return .leaf
    }

    private static func startListItem(_ parser: BlockParser, _ container: Block) -> BlockStartResult {
        guard !parser.isIndented || container is List, let marker = parseListMarker(parser, container) else { return .none }
        parser.closeUnmatchedBlocks()
        if !((parser.tip as? List).map { $0.marker.kind == marker.kind } ?? false) {
            parser.addChild(List(marker: marker))
        }
        parser.addChild(ListItem(marker: marker))
        return .container
    }

    private static func startIndentedCode(_ parser: BlockParser, _ container: Block) -> BlockStartResult {
        guard parser.isIndented, !(parser.tip is Paragraph), !parser.isBlank else { return .none }
        parser.advanceOffset(BlockParser.codeIndent, columns: true)
        parser.closeUnmatchedBlocks()
        parser.addChild(CodeBlock())
        return .leaf
    }

    private static func parseListMarker(_ parser: BlockParser, _ container: Block) -> ListMarker? {
        guard parser.indent < BlockParser.codeIndent, let first = parser.line.at(parser.nextNonspace) else { return nil }
        let line = parser.line
        let kind: ListMarker.Kind
        var start = 1
        var markerLength = 1
        if first == Byte.asterisk || first == Byte.plus || first == Byte.dash {
            kind = .bullet(first)
        } else if Byte.isDigit(first) {
            var end = parser.nextNonspace
            var value = 0
            while let digit = line.at(end), Byte.isDigit(digit), end - parser.nextNonspace < 9 {
                value = value * 10 + Int(digit - 0x30)
                end += 1
            }
            guard let delimiter = line.at(end), delimiter == Byte.dot || delimiter == Byte.closeParen else { return nil }
            // Only a list starting at 1 can interrupt a paragraph.
            if container is Paragraph, value != 1 { return nil }
            kind = .ordered(delimiter: delimiter)
            start = value
            markerLength = end - parser.nextNonspace + 1
        } else {
            return nil
        }

        let afterMarker = parser.nextNonspace + markerLength
        if let following = line.at(afterMarker), !Byte.isSpaceOrTab(following) { return nil }
        // An empty item cannot interrupt a paragraph.
        if container is Paragraph, line.isBlank(from: afterMarker) { return nil }

        let markerOffset = parser.indent
        parser.advanceNextNonspace()
        parser.advanceOffset(markerLength, columns: true)
        let spacesStartColumn = parser.column
        let spacesStartOffset = parser.offset
        repeat {
            parser.advanceOffset(1, columns: true)
        } while parser.column - spacesStartColumn < 5 && Byte.isSpaceOrTab(line.at(parser.offset))
        let isBlankItem = parser.offset >= line.count
        let spacesAfterMarker = parser.column - spacesStartColumn
        let padding: Int
        if spacesAfterMarker >= 5 || spacesAfterMarker < 1 || isBlankItem {
            // The content starts with indented code or is empty: only one space belongs to the marker.
            padding = markerLength + 1
            parser.rewind(toOffset: spacesStartOffset, column: spacesStartColumn)
            if Byte.isSpaceOrTab(line.at(parser.offset)) { parser.advanceOffset(1, columns: true) }
        } else {
            padding = markerLength + spacesAfterMarker
        }
        return ListMarker(kind: kind, start: start, padding: padding, markerOffset: markerOffset)
    }
}

/// Line-level syntax of leaf blocks.
public enum BlockSyntax {
    /// Three or more `*`, `-` or `_`, optionally separated by spaces or tabs, and nothing else.
    public static func isThematicBreak(_ line: [UInt8], from start: Int) -> Bool {
        guard let marker = line.at(start), marker == Byte.asterisk || marker == Byte.dash || marker == Byte.underscore else { return false }
        var count = 0
        for byte in line[start...] {
            if byte == marker { count += 1 } else if !Byte.isSpaceOrTab(byte) { return false }
        }
        return count >= 3
    }
}

/// Start and end conditions of HTML blocks (CommonMark 0.31.2, section 4.6).
enum HTMLBlockSyntax {
    private static let verbatimTags = ["script", "pre", "textarea", "style"]

    private static let blockTags: Set<String> = [
        "address", "article", "aside", "base", "basefont", "blockquote", "body", "caption", "center", "col", "colgroup",
        "dd", "details", "dialog", "dir", "div", "dl", "dt", "fieldset", "figcaption", "figure", "footer", "form", "frame",
        "frameset", "h1", "h2", "h3", "h4", "h5", "h6", "head", "header", "hr", "html", "iframe", "legend", "li", "link",
        "main", "menu", "menuitem", "nav", "noframes", "ol", "optgroup", "option", "p", "param", "search", "section",
        "summary", "table", "tbody", "td", "tfoot", "th", "thead", "title", "tr", "track", "ul",
    ]

    /// - Parameter start: index of the `<`.
    static func startCondition(_ line: [UInt8], from start: Int) -> Int? {
        let afterBracket = start + 1
        for tag in verbatimTags where line.hasPrefix(tag, at: afterBracket, caseInsensitive: true) {
            let end = afterBracket + tag.utf8.count
            if end == line.count || Byte.isWhitespace(line[end]) || line[end] == Byte.greaterThan { return 1 }
        }
        if line.hasPrefix("!--", at: afterBracket) { return 2 }
        if line.at(afterBracket) == Byte.question { return 3 }
        if line.at(afterBracket) == Byte.bang, let letter = line.at(afterBracket + 1), Byte.isLetter(letter) { return 4 }
        if line.hasPrefix("![CDATA[", at: afterBracket) { return 5 }

        var nameStart = afterBracket
        if line.at(nameStart) == Byte.slash { nameStart += 1 }
        var nameEnd = nameStart
        while let byte = line.at(nameEnd), Byte.isAlphanumeric(byte) { nameEnd += 1 }
        if nameEnd > nameStart, blockTags.contains(line.string(nameStart..<nameEnd).lowercased()) {
            if nameEnd == line.count || Byte.isWhitespace(line[nameEnd]) || line[nameEnd] == Byte.greaterThan
                || (line[nameEnd] == Byte.slash && line.at(nameEnd + 1) == Byte.greaterThan) { return 6 }
        }

        if let end = HTMLTagScanner.scanOpenOrClosingTag(line, at: start), line[end...].allSatisfy(Byte.isWhitespace) { return 7 }
        return nil
    }

    /// Whether the line (from `start`) meets the end condition of an HTML block opened by conditions 1 to 5.
    static func closes(condition: Int, line: [UInt8], from start: Int) -> Bool {
        let rest = Array(line[min(start, line.count)...])
        switch condition {
        case 1: return verbatimTags.contains { contains(rest, "</\($0)>", caseInsensitive: true) }
        case 2: return contains(rest, "-->")
        case 3: return contains(rest, "?>")
        case 4: return rest.contains(Byte.greaterThan)
        case 5: return contains(rest, "]]>")
        default: return false
        }
    }

    private static func contains(_ bytes: [UInt8], _ ascii: String, caseInsensitive: Bool = false) -> Bool {
        let length = ascii.utf8.count
        guard bytes.count >= length else { return false }
        for index in 0...(bytes.count - length) where bytes.hasPrefix(ascii, at: index, caseInsensitive: caseInsensitive) { return true }
        return false
    }
}

/// Raw HTML constructs (CommonMark 0.31.2, section 6.6).
enum HTMLTagScanner {
    /// Scans any raw HTML construct starting at the `<` at `start`.
    /// - Returns: the index after the construct, or nil.
    static func scan(_ bytes: [UInt8], at start: Int) -> Int? {
        guard bytes.at(start) == Byte.lessThan, let next = bytes.at(start + 1) else { return nil }
        switch next {
        case Byte.bang:
            if bytes.hasPrefix("--", at: start + 2) { return scanComment(bytes, at: start) }
            if bytes.hasPrefix("[CDATA[", at: start + 2) { return index(of: "]]>", in: bytes, from: start + 9).map { $0 + 3 } }
            if let letter = bytes.at(start + 2), Byte.isLetter(letter) {
                return bytes[(start + 2)...].firstIndex(of: Byte.greaterThan).map { $0 + 1 }
            }
            return nil
        case Byte.question:
            return index(of: "?>", in: bytes, from: start + 2).map { $0 + 2 }
        default:
            return scanOpenOrClosingTag(bytes, at: start)
        }
    }

    /// `<!-->`, `<!--->`, or `<!--` … `-->`.
    private static func scanComment(_ bytes: [UInt8], at start: Int) -> Int? {
        let textStart = start + 4
        if bytes.at(textStart) == Byte.greaterThan { return textStart + 1 }
        if bytes.at(textStart) == Byte.dash, bytes.at(textStart + 1) == Byte.greaterThan { return textStart + 2 }
        return index(of: "-->", in: bytes, from: textStart).map { $0 + 3 }
    }

    static func scanOpenOrClosingTag(_ bytes: [UInt8], at start: Int) -> Int? {
        guard bytes.at(start) == Byte.lessThan else { return nil }
        var position = start + 1
        let isClosing = bytes.at(position) == Byte.slash
        if isClosing { position += 1 }
        guard let first = bytes.at(position), Byte.isLetter(first) else { return nil }
        while let byte = bytes.at(position), Byte.isAlphanumeric(byte) || byte == Byte.dash { position += 1 }

        if isClosing {
            position = skipWhitespace(bytes, position)
            return bytes.at(position) == Byte.greaterThan ? position + 1 : nil
        }

        while true {
            let afterWhitespace = skipWhitespace(bytes, position)
            guard afterWhitespace > position, let nameStart = bytes.at(afterWhitespace),
                  Byte.isLetter(nameStart) || nameStart == Byte.underscore || nameStart == Byte.colon else {
                position = afterWhitespace
                break
            }
            position = afterWhitespace + 1
            while let byte = bytes.at(position),
                  Byte.isAlphanumeric(byte) || byte == Byte.underscore || byte == Byte.dot || byte == Byte.colon || byte == Byte.dash {
                position += 1
            }
            // Optional value specification.
            let beforeEquals = skipWhitespace(bytes, position)
            guard bytes.at(beforeEquals) == Byte.equals else { continue }
            let valueStart = skipWhitespace(bytes, beforeEquals + 1)
            guard let opening = bytes.at(valueStart) else { return nil }
            if opening == Byte.singleQuote || opening == Byte.doubleQuote {
                guard let closing = bytes[(valueStart + 1)...].firstIndex(of: opening) else { return nil }
                position = closing + 1
            } else {
                var end = valueStart
                while let byte = bytes.at(end), !Byte.isWhitespace(byte), byte != Byte.doubleQuote, byte != Byte.singleQuote,
                      byte != Byte.equals, byte != Byte.lessThan, byte != Byte.greaterThan, byte != Byte.backtick {
                    end += 1
                }
                guard end > valueStart else { return nil }
                position = end
            }
        }
        if bytes.at(position) == Byte.slash { position += 1 }
        return bytes.at(position) == Byte.greaterThan ? position + 1 : nil
    }

    private static func skipWhitespace(_ bytes: [UInt8], _ start: Int) -> Int {
        var position = start
        while let byte = bytes.at(position), Byte.isWhitespace(byte) { position += 1 }
        return position
    }

    private static func index(of ascii: String, in bytes: [UInt8], from start: Int) -> Int? {
        let length = ascii.utf8.count
        guard start >= 0, bytes.count - length >= start else { return nil }
        for index in start...(bytes.count - length) where bytes.hasPrefix(ascii, at: index) { return index }
        return nil
    }
}

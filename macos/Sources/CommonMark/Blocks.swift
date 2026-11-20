/// How an open block reacts to the next line.
public enum BlockContinuation {
    /// The line continues this block.
    case matched
    /// The line does not belong to this block.
    case notMatched
    /// The line closed this block and is fully consumed.
    case consumedLine
}

/// A block-level node. Subclasses define how the block continues over lines and what it may contain.
open class Block: Node {
    /// First source line (0-based).
    public internal(set) var startLine = 0
    /// Last source line holding content of this block (0-based).
    public var endLine = 0

    public internal(set) var isOpen = true
    var lastLineBlank = false
    var lastLineChecked = false

    /// Unparsed text of a leaf block; inline-bearing blocks have it parsed into children after block parsing.
    public var rawContent: [UInt8] = []

    /// True when lines are appended to `rawContent` rather than starting child blocks.
    open var acceptsLines: Bool { false }

    /// True when `rawContent` is parsed as inline content.
    open var containsInlines: Bool { false }

    open func canContain(_ child: Block) -> Bool { false }

    open func continuation(_ parser: BlockParser) -> BlockContinuation { .notMatched }

    /// Appends the rest of the current line. Only called when `acceptsLines`.
    open func addLine(_ parser: BlockParser) {
        parser.appendRestOfLine(to: &rawContent)
    }

    /// Called once when the block is closed.
    open func finalize(_ parser: BlockParser) {}

    /// The last source line covered by this block or its descendants.
    public var lastContentLine: Int {
        var last = endLine
        var child = lastChild
        while let block = child as? Block {
            last = max(last, block.endLine)
            child = block.lastChild
        }
        return max(last, startLine)
    }
}

public final class Document: Block {
    /// Link reference definitions by normalized label.
    public internal(set) var references: [String: LinkReference] = [:]

    /// Data attached by extensions while parsing (e.g. footnote definitions, flags for usage probes).
    public var userData: [String: Any] = [:]

    public override func canContain(_ child: Block) -> Bool { !(child is ListItem) }

    public override func continuation(_ parser: BlockParser) -> BlockContinuation { .matched }
}

public struct LinkReference {
    public let destination: String
    public let title: String?
}

public final class Paragraph: Block {
    public override var acceptsLines: Bool { true }

    public override var containsInlines: Bool { true }

    public override func continuation(_ parser: BlockParser) -> BlockContinuation {
        parser.isBlank ? .notMatched : .matched
    }

    /// Leading link reference definitions are moved to the document; a paragraph made only of them disappears.
    public override func finalize(_ parser: BlockParser) {
        guard parser.consumeReferenceDefinitions(from: self), rawContent.allSatisfy(Byte.isWhitespace) else { return }
        unlink()
    }

    public override func writeHTML(to renderer: HTMLRenderer) {
        if let item = parent as? ListItem, let list = item.parent as? List, list.isTight {
            renderer.renderChildren(of: self)
            return
        }
        renderer.ensureLine()
        renderer.write("<p")
        renderer.writeAttributes(of: self)
        renderer.write(">")
        renderer.renderChildren(of: self)
        renderer.write("</p>\n")
    }
}

public final class Heading: Block {
    public var level: Int

    public init(level: Int) {
        self.level = level
    }

    public override var containsInlines: Bool { true }

    public override func writeHTML(to renderer: HTMLRenderer) {
        renderer.ensureLine()
        renderer.write("<h\(level)")
        renderer.writeAttributes(of: self)
        renderer.write(">")
        renderer.renderChildren(of: self)
        renderer.write("</h\(level)>\n")
    }
}

public final class ThematicBreak: Block {
    public override func writeHTML(to renderer: HTMLRenderer) {
        renderer.ensureLine()
        renderer.write("<hr")
        renderer.writeAttributes(of: self)
        renderer.write(" />\n")
    }
}

public final class BlockQuote: Block {
    public override func canContain(_ child: Block) -> Bool { !(child is ListItem) }

    public override func continuation(_ parser: BlockParser) -> BlockContinuation {
        guard !parser.isIndented, parser.line.at(parser.nextNonspace) == Byte.greaterThan else { return .notMatched }
        parser.advanceNextNonspace()
        parser.advanceOffset(1, columns: false)
        if Byte.isSpaceOrTab(parser.line.at(parser.offset)) { parser.advanceOffset(1, columns: true) }
        return .matched
    }

    public override func writeHTML(to renderer: HTMLRenderer) {
        renderer.ensureLine()
        renderer.write("<blockquote")
        renderer.writeAttributes(of: self)
        renderer.write(">\n")
        renderer.renderChildren(of: self)
        renderer.ensureLine()
        renderer.write("</blockquote>\n")
    }
}

/// What makes two list items belong to the same list, plus the geometry of the item's marker.
public struct ListMarker {
    public enum Kind: Equatable {
        case bullet(UInt8)
        case ordered(delimiter: UInt8)
    }

    public var kind: Kind
    /// First number of an ordered list.
    public var start: Int
    /// Width of the marker and the spaces after it: the indentation continuation lines need.
    var padding: Int
    /// Indentation of the marker itself.
    var markerOffset: Int
}

public final class List: Block {
    public let marker: ListMarker
    public internal(set) var isTight = true

    init(marker: ListMarker) {
        self.marker = marker
    }

    public var isOrdered: Bool {
        if case .ordered = marker.kind { return true }
        return false
    }

    public override func canContain(_ child: Block) -> Bool { child is ListItem }

    public override func continuation(_ parser: BlockParser) -> BlockContinuation { .matched }

    /// A list is loose when any of its items, or any block directly inside an item, is followed by a blank line.
    public override func finalize(_ parser: BlockParser) {
        var item = firstChild as? Block
        while let current = item {
            if current.next != nil, current.endsWithBlankLine {
                isTight = false
                break
            }
            var child = current.firstChild as? Block
            while let block = child {
                if block.next != nil || current.next != nil, block.endsWithBlankLine {
                    isTight = false
                    break
                }
                child = block.next as? Block
            }
            if !isTight { break }
            item = current.next as? Block
        }
    }

    public override func writeHTML(to renderer: HTMLRenderer) {
        let tag = isOrdered ? "ol" : "ul"
        renderer.ensureLine()
        renderer.write("<\(tag)")
        if isOrdered, marker.start != 1 { renderer.write(" start=\"\(marker.start)\"") }
        renderer.writeAttributes(of: self)
        renderer.write(">\n")
        renderer.renderChildren(of: self)
        renderer.ensureLine()
        renderer.write("</\(tag)>\n")
    }
}

public final class ListItem: Block {
    let marker: ListMarker

    init(marker: ListMarker) {
        self.marker = marker
    }

    public override func canContain(_ child: Block) -> Bool { !(child is ListItem) }

    public override func continuation(_ parser: BlockParser) -> BlockContinuation {
        if parser.isBlank {
            // A blank line after an empty list item ends it.
            guard firstChild != nil else { return .notMatched }
            parser.advanceNextNonspace()
        } else if parser.indent >= marker.markerOffset + marker.padding {
            parser.advanceOffset(marker.markerOffset + marker.padding, columns: true)
        } else {
            return .notMatched
        }
        return .matched
    }

    public override func writeHTML(to renderer: HTMLRenderer) {
        renderer.ensureLine()
        renderer.write("<li")
        renderer.writeAttributes(of: self)
        renderer.write(">")
        renderer.renderChildren(of: self)
        renderer.write("</li>\n")
    }
}

public final class CodeBlock: Block {
    public internal(set) var isFenced = false
    var fenceCharacter: UInt8 = 0
    var fenceLength = 0
    var fenceOffset = 0

    /// The info string of a fenced block (empty for indented code).
    public internal(set) var info = ""
    public internal(set) var literal = ""

    /// The first word of the info string: the language.
    public var language: String {
        String(info.prefix { !$0.isWhitespace })
    }

    public override var acceptsLines: Bool { true }

    public override func continuation(_ parser: BlockParser) -> BlockContinuation {
        let line = parser.line
        if isFenced {
            if parser.indent <= 3, line.at(parser.nextNonspace) == fenceCharacter {
                var end = parser.nextNonspace
                while line.at(end) == fenceCharacter { end += 1 }
                if end - parser.nextNonspace >= fenceLength, line.isBlank(from: end) {
                    endLine = parser.lineNumber
                    parser.finalize(self)
                    return .consumedLine
                }
            }
            var skipped = fenceOffset
            while skipped > 0, Byte.isSpaceOrTab(line.at(parser.offset)) {
                parser.advanceOffset(1, columns: true)
                skipped -= 1
            }
        } else if parser.indent >= BlockParser.codeIndent {
            parser.advanceOffset(BlockParser.codeIndent, columns: true)
        } else if parser.isBlank {
            parser.advanceNextNonspace()
        } else {
            return .notMatched
        }
        return .matched
    }

    public override func finalize(_ parser: BlockParser) {
        if isFenced {
            // The first line is the info string.
            let firstLineEnd = rawContent.firstIndex(of: Byte.newline) ?? rawContent.count
            var infoBytes = Array(rawContent[..<firstLineEnd])
            while let last = infoBytes.last, Byte.isWhitespace(last) { infoBytes.removeLast() }
            let infoStart = infoBytes.firstIndex { !Byte.isWhitespace($0) } ?? infoBytes.count
            info = Unescaping.unescape(Array(infoBytes[infoStart...]))
            literal = firstLineEnd < rawContent.count ? rawContent.string((firstLineEnd + 1)..<rawContent.count) : ""
        } else {
            // Trailing blank lines are not part of indented code.
            var lines = rawContent.split(separator: Byte.newline, omittingEmptySubsequences: false).map(Array.init)
            var removed = 0
            while let last = lines.last, last.isBlank(from: 0) {
                lines.removeLast()
                removed += 1
            }
            literal = lines.map(\.string).joined(separator: "\n") + "\n"
            endLine = startLine + max(0, lines.count - 1)
        }
        rawContent = []
    }

    public override func writeHTML(to renderer: HTMLRenderer) {
        renderer.ensureLine()
        renderer.write("<pre><code")
        let language = self.language
        if !language.isEmpty {
            renderer.write(" class=\"language-")
            renderer.writeEscaped(language)
            renderer.write("\"")
        }
        renderer.writeAttributes(of: self)
        renderer.write(">")
        renderer.writeEscaped(literal)
        renderer.write("</code></pre>\n")
    }
}

public final class HTMLBlock: Block {
    /// Start condition (1 to 7) of the CommonMark specification, which decides how the block ends.
    let condition: Int
    public var literal = ""

    init(condition: Int) {
        self.condition = condition
    }

    public override var acceptsLines: Bool { true }

    public override func continuation(_ parser: BlockParser) -> BlockContinuation {
        parser.isBlank && (condition == 6 || condition == 7) ? .notMatched : .matched
    }

    public override func finalize(_ parser: BlockParser) {
        var content = rawContent
        if content.last == Byte.newline { content.removeLast() }
        literal = content.string
        rawContent = []
    }

    public override func writeHTML(to renderer: HTMLRenderer) {
        renderer.ensureLine()
        renderer.write(literal)
        renderer.ensureLine()
    }
}

extension Block {
    /// True when the block ends with a blank line, looking into the last items of nested lists.
    var endsWithBlankLine: Bool {
        var block: Block? = self
        while let current = block {
            if current.lastLineBlank { return true }
            if !current.lastLineChecked, current is List || current is ListItem {
                current.lastLineChecked = true
                block = current.lastChild as? Block
            } else {
                current.lastLineChecked = true
                break
            }
        }
        return false
    }
}

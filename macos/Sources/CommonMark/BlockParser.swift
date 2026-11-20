/// Outcome of trying to start a block on the current line.
public enum BlockStartResult {
    /// The line does not start this kind of block.
    case none
    /// A container was opened; the rest of the line may start further blocks.
    case container
    /// A leaf was opened; the rest of the line is its content.
    case leaf
}

/// A way to open a block, tried on each line that is not the continuation of a leaf.
public struct BlockStart {
    /// First non-blank bytes of a line this start can apply to; nil for any.
    public let openingCharacters: Set<UInt8>?
    /// - Parameters:
    ///   - parser: positioned on the line; `nextNonspace` is its first non-blank byte.
    ///   - container: the innermost block the line continues (a `Paragraph` when the start would interrupt one).
    public let tryStart: (_ parser: BlockParser, _ container: Block) -> BlockStartResult

    public init(openingCharacters: Set<UInt8>?, tryStart: @escaping (BlockParser, Block) -> BlockStartResult) {
        self.openingCharacters = openingCharacters
        self.tryStart = tryStart
    }
}

/// Builds the block structure of a document line by line, following the CommonMark parsing strategy:
/// each line first continues the open blocks it matches, then may open new blocks, then adds its text
/// to the innermost open leaf.
public final class BlockParser {
    static let codeIndent = 4
    /// Containers nested deeper than this are treated as text, so hostile input cannot exhaust the stack.
    static let maxNesting = 200

    public let document = Document()
    /// All lines of the input, without line endings.
    public let lines: [[UInt8]]
    /// Index of the current line (0-based).
    public private(set) var lineNumber = 0
    /// The current line.
    public private(set) var line: [UInt8] = []
    /// Byte offset of the parse position in `line`.
    public private(set) var offset = 0
    /// Column of the parse position (tabs expand to the next multiple of 4).
    public private(set) var column = 0
    public private(set) var nextNonspace = 0
    private var nextNonspaceColumn = 0
    /// Columns of indentation between the parse position and the first non-blank byte.
    public private(set) var indent = 0
    public private(set) var isIndented = false
    public private(set) var isBlank = false
    private var partiallyConsumedTab = false

    /// The innermost open block.
    public var tip: Block
    private var oldTip: Block
    private var lastMatchedContainer: Block
    private var allClosed = true

    private let starts: [BlockStart]
    private let mayStartBlock: [Bool]
    private let hasUnconditionalStart: Bool

    init(lines: [[UInt8]], extensionStarts: [BlockStart]) {
        self.lines = lines
        tip = document
        oldTip = document
        lastMatchedContainer = document
        starts = extensionStarts + BlockParser.coreStarts
        var table = [Bool](repeating: false, count: 256)
        for byte in "#`~*+_=<>0123456789-".utf8 { table[Int(byte)] = true }
        var unconditional = false
        for start in extensionStarts {
            if let characters = start.openingCharacters {
                for byte in characters { table[Int(byte)] = true }
            } else {
                unconditional = true
            }
        }
        mayStartBlock = table
        hasUnconditionalStart = unconditional
    }

    func parse() -> Document {
        for index in lines.indices {
            lineNumber = index
            incorporateLine(lines[index])
        }
        lineNumber = max(0, lines.count - 1)
        while tip !== document { finalize(tip) }
        finalize(document)
        document.endLine = max(0, lines.count - 1)
        return document
    }

    // MARK: Position

    /// The rest of the current line from the parse position.
    public var restOfLine: [UInt8] { Array(line[min(offset, line.count)...]) }

    /// The rest of the current line from its first non-blank byte.
    public var restFromNonspace: [UInt8] { Array(line[min(nextNonspace, line.count)...]) }

    func findNextNonspace() {
        var index = offset
        var columns = column
        while index < line.count {
            let byte = line[index]
            if byte == Byte.space {
                index += 1
                columns += 1
            } else if byte == Byte.tab {
                index += 1
                columns += 4 - (columns % 4)
            } else {
                break
            }
        }
        isBlank = index >= line.count
        nextNonspace = index
        nextNonspaceColumn = columns
        indent = nextNonspaceColumn - column
        isIndented = indent >= BlockParser.codeIndent
    }

    public func advanceNextNonspace() {
        offset = nextNonspace
        column = nextNonspaceColumn
        partiallyConsumedTab = false
    }

    /// Advances by `count` bytes, or by `count` columns (a tab may then be consumed in part).
    public func advanceOffset(_ count: Int, columns: Bool) {
        var remaining = count
        while remaining > 0, offset < line.count {
            if line[offset] == Byte.tab {
                let toTabStop = 4 - (column % 4)
                if columns {
                    partiallyConsumedTab = toTabStop > remaining
                    let advance = min(toTabStop, remaining)
                    column += advance
                    offset += partiallyConsumedTab ? 0 : 1
                    remaining -= advance
                } else {
                    partiallyConsumedTab = false
                    column += toTabStop
                    offset += 1
                    remaining -= 1
                }
            } else {
                partiallyConsumedTab = false
                offset += 1
                column += 1
                remaining -= 1
            }
        }
    }

    /// True when every block open before this line was continued by it.
    public var allBlocksClosed: Bool { allClosed }

    func rewind(toOffset offset: Int, column: Int) {
        self.offset = offset
        self.column = column
        partiallyConsumedTab = false
    }

    public func advanceToEndOfLine() {
        advanceOffset(line.count - offset, columns: false)
    }

    /// Appends the rest of the line and a line feed; a partially consumed tab contributes its remaining spaces.
    public func appendRestOfLine(to content: inout [UInt8]) {
        if partiallyConsumedTab {
            offset += 1
            content.append(contentsOf: repeatElement(Byte.space, count: 4 - (column % 4)))
            partiallyConsumedTab = false
        }
        if offset < line.count { content.append(contentsOf: line[offset...]) }
        content.append(Byte.newline)
    }

    // MARK: Tree building

    /// Adds `block` under the innermost open block able to contain it, closing the blocks that cannot.
    @discardableResult
    public func addChild<T: Block>(_ block: T) -> T {
        while !tip.canContain(block), tip !== document { finalize(tip) }
        block.startLine = lineNumber
        block.endLine = lineNumber
        tip.appendChild(block)
        tip = block
        return block
    }

    /// Closes the open blocks the current line did not continue.
    public func closeUnmatchedBlocks() {
        guard !allClosed else { return }
        while oldTip !== lastMatchedContainer, let parent = oldTip.parent as? Block {
            finalize(oldTip)
            oldTip = parent
        }
        allClosed = true
    }

    public func finalize(_ block: Block) {
        let above = block.parent as? Block
        block.isOpen = false
        block.finalize(self)
        tip = above ?? document
    }

    /// Moves link reference definitions at the start of the paragraph to the document.
    /// - Returns: true when at least one definition was found.
    func consumeReferenceDefinitions(from paragraph: Block) -> Bool {
        var found = false
        while paragraph.rawContent.first == Byte.openBracket {
            let consumed = InlineParser.parseReferenceDefinition(paragraph.rawContent, into: document)
            guard consumed > 0 else { break }
            paragraph.rawContent.removeFirst(consumed)
            found = true
        }
        return found
    }

    private var nestingDepth: Int {
        var depth = 0
        var block: Node? = tip
        while let current = block {
            depth += 1
            block = current.parent
        }
        return depth
    }

    // MARK: Line incorporation

    private func incorporateLine(_ text: [UInt8]) {
        var container: Block = document
        oldTip = tip
        offset = 0
        column = 0
        isBlank = false
        partiallyConsumedTab = false
        line = text

        // Continue the open blocks the line matches; `container` ends as the last matching one.
        while let lastChild = container.lastChild as? Block, lastChild.isOpen {
            findNextNonspace()
            switch lastChild.continuation(self) {
            case .matched:
                container = lastChild
                continue
            case .consumedLine:
                return
            case .notMatched:
                break
            }
            break
        }

        allClosed = container === oldTip
        lastMatchedContainer = container

        // Unless the line continues a leaf that takes lines, try to start new blocks.
        var matchedLeaf = !(container is Paragraph) && container.acceptsLines
        startLoop: while !matchedLeaf {
            findNextNonspace()
            let first = line.at(nextNonspace)
            if !isIndented, !hasUnconditionalStart, !(first.map { mayStartBlock[Int($0)] } ?? false) {
                advanceNextNonspace()
                break
            }
            var started = BlockStartResult.none
            if nestingDepth < BlockParser.maxNesting {
                for start in starts {
                    if let characters = start.openingCharacters, !(first.map(characters.contains) ?? false) { continue }
                    started = start.tryStart(self, container)
                    if case .none = started { continue }
                    break
                }
            }
            switch started {
            case .none:
                advanceNextNonspace()
                break startLoop
            case .container:
                container = tip
            case .leaf:
                container = tip
                matchedLeaf = true
            }
        }

        // What remains is text for the innermost block.
        if !allClosed, !isBlank, tip is Paragraph {
            // Lazy paragraph continuation.
            tip.addLine(self)
            tip.endLine = lineNumber
        } else {
            closeUnmatchedBlocks()
            if isBlank, let last = container.lastChild as? Block { last.lastLineBlank = true }

            // Blank lines in block quotes and fenced code do not count for list tightness, nor does
            // the marker line of an empty list item.
            let lastLineBlank = isBlank && !(container is BlockQuote
                || (container as? CodeBlock)?.isFenced == true
                || (container is ListItem && container.firstChild == nil && container.startLine == lineNumber))
            var ancestor: Block? = container
            while let current = ancestor {
                current.lastLineBlank = lastLineBlank
                ancestor = current.parent as? Block
            }

            if container.acceptsLines {
                container.addLine(self)
                if !isBlank || (container as? CodeBlock)?.isFenced == true || container is HTMLBlock { container.endLine = lineNumber }
                if let html = container as? HTMLBlock, html.condition <= 5, html.isOpen,
                   HTMLBlockSyntax.closes(condition: html.condition, line: line, from: offset) {
                    finalize(html)
                }
            } else if offset < line.count, !isBlank {
                let paragraph = addChild(Paragraph())
                advanceNextNonspace()
                paragraph.addLine(self)
            }
        }
    }
}

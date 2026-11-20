import CommonMark
import MarkdownEditorCore

/// Math as on GitHub: `$inline$`, ``$`inline`$``, `$$block$$` and ```` ```math ```` fences, typeset in the
/// preview by a bundled KaTeX.
public struct MathPlugin: MarkdownPlugin, DocumentFeatureProbe {
    public static let pluginID = "math"
    public static let katexVersion = "0.19.1"
    public static let vendorFolder = "assets/vendor/katex-\(katexVersion)"
    public static let katexScriptPath = "\(vendorFolder)/katex.min.js"
    public static let katexStylesheetPath = "\(vendorFolder)/katex.min.css"
    public static let bootstrapScriptPath = "assets/math.js"
    public static let stylesheetPath = "assets/math.css"
    public static let mathFenceLanguage = "math"

    private static let dollar = UInt8(ascii: "$")

    public init() {}

    public var id: String { Self.pluginID }
    public var name: String { "Math" }
    public var version: PluginVersion { PluginVersion(1, 0, 0) }
    public var previewAssets: [PreviewAsset] {
        [.stylesheet(Self.katexStylesheetPath), .stylesheet(Self.stylesheetPath), .script(Self.katexScriptPath), .script(Self.bootstrapScriptPath)]
    }

    public func isUsed(by document: Document) -> Bool {
        document.hasDescendant(ofType: MathInline.self) || document.hasDescendant(ofType: MathBlock.self)
            || document.hasDescendant(ofType: CodeBlock.self) { $0.isFenced && $0.language == Self.mathFenceLanguage }
    }

    public func configurePipeline(_ builder: MarkdownPipelineBuilder) {
        builder.addBlockStart(BlockStart(openingCharacters: [Self.dollar], tryStart: Self.startBlock))
        builder.addInlineStart(InlineStart(triggerCharacters: [Self.dollar], tryParse: Self.parseInline))
    }

    /// A line made of two or more `$` opens display math, closed by a line of at least as many.
    private static func startBlock(_ parser: BlockParser, _ container: Block) -> BlockStartResult {
        guard !parser.isIndented, let fenceLength = MathBlock.fenceLength(parser.line, from: parser.nextNonspace) else { return .none }
        parser.closeUnmatchedBlocks()
        parser.addChild(MathBlock(fenceLength: fenceLength))
        parser.advanceToEndOfLine()
        return .leaf
    }

    /// `$…$` or `$$…$$` on one line. To leave prices alone, the opening `$` must follow whitespace or
    /// punctuation, the closing `$` must precede whitespace or punctuation, and the expression is either
    /// padded with spaces on both sides or on neither.
    private static func parseInline(_ parser: InlineParser) -> Bool {
        let before = parser.scalarBefore
        guard before != "$", UnicodeClass.isWhitespace(before) || UnicodeClass.isPunctuation(before) else { return false }
        var index = parser.position + 1
        var openLength = 1
        if parser.byte(at: index) == dollar {
            openLength = 2
            index += 1
        }
        let opensWithWhitespace = UnicodeClass.isWhitespace(parser.scalar(at: index))
        while let byte = parser.byte(at: index), byte == 0x20 || byte == 0x09 { index += 1 }
        let contentStart = index

        var previous = dollar
        var closeStart: Int?
        var closeEnd = index
        while let byte = parser.byte(at: index) {
            if byte == 0x0A || byte == 0x0D { return false }
            if previous != UInt8(ascii: "\\"), byte == dollar {
                var runEnd = index
                while parser.byte(at: runEnd) == dollar { runEnd += 1 }
                if runEnd - index >= openLength {
                    closeStart = index
                    closeEnd = runEnd
                    break
                }
                index = runEnd
                previous = dollar
                continue
            }
            previous = byte
            index += 1
        }
        guard let closeStart, closeStart > contentStart else { return false }

        let after = parser.scalar(at: closeEnd)
        let closesAfterWhitespace = UnicodeClass.isWhitespace(parser.scalar(before: closeStart))
        guard UnicodeClass.isWhitespace(after) || UnicodeClass.isPunctuation(after), opensWithWhitespace == closesAfterWhitespace else { return false }

        var content = parser.text(contentStart..<closeStart)
        while content.last == " " || content.last == "\t" { content.removeLast() }
        // GitHub's $`…`$ form: the backticks only delimit the expression.
        if content.count >= 2, content.first == "`", content.last == "`" { content = String(content.dropFirst().dropLast()) }
        parser.append(MathInline(content))
        parser.position = closeEnd
        return true
    }
}

final class MathInline: Inline {
    let content: String

    init(_ content: String) {
        self.content = content
        super.init()
        attributes.addClass("math")
    }

    override func writeHTML(to renderer: HTMLRenderer) {
        if renderer.isWritingPlainText {
            renderer.writeEscaped(content)
            return
        }
        renderer.write("<span")
        renderer.writeAttributes(of: self)
        renderer.write(">\\(")
        renderer.writeEscaped(content)
        renderer.write("\\)</span>")
    }

    override var plainText: String { content }
}

final class MathBlock: Block {
    private let fenceLength: Int

    init(fenceLength: Int) {
        self.fenceLength = fenceLength
        super.init()
        attributes.addClass("math")
    }

    /// Number of `$` when the line, from `start`, is only a run of two or more `$` (trailing blanks allowed).
    static func fenceLength(_ line: [UInt8], from start: Int) -> Int? {
        var end = start
        while end < line.count, line[end] == UInt8(ascii: "$") { end += 1 }
        guard end - start >= 2, line[end...].allSatisfy({ $0 == 0x20 || $0 == 0x09 }) else { return nil }
        return end - start
    }

    override var acceptsLines: Bool { true }

    override func continuation(_ parser: BlockParser) -> BlockContinuation {
        if !parser.isIndented, let length = Self.fenceLength(parser.line, from: parser.nextNonspace), length >= fenceLength {
            endLine = parser.lineNumber
            parser.finalize(self)
            return .consumedLine
        }
        return .matched
    }

    override func addLine(_ parser: BlockParser) {
        guard parser.lineNumber > startLine else { return } // the opening fence
        super.addLine(parser)
        endLine = parser.lineNumber
    }

    override func writeHTML(to renderer: HTMLRenderer) {
        renderer.ensureLine()
        renderer.write("<div")
        renderer.writeAttributes(of: self)
        renderer.write(">\n\\[\n")
        renderer.writeEscaped(String(decoding: rawContent, as: UTF8.self))
        renderer.write("\\]</div>\n")
    }
}

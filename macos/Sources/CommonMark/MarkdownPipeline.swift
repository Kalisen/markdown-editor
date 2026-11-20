/// Collects the extensions of a Markdown dialect. Without extensions the pipeline is strict CommonMark.
public final class MarkdownPipelineBuilder {
    var blockStarts: [BlockStart] = []
    var inlineStarts: [InlineStart] = []
    var delimiters: [EmphasisDelimiter] = EmphasisDelimiter.core
    var documentProcessors: [(key: String, process: (Document) -> Void)] = []
    var renderingWrappers: [ObjectIdentifier: [HTMLRenderer.Wrapper]] = [:]

    public init() {}

    /// Adds a block start, tried before the CommonMark ones and before those added earlier.
    public func addBlockStart(_ start: BlockStart) {
        blockStarts.insert(start, at: 0)
    }

    /// Adds an inline construct, tried before the CommonMark rules.
    public func addInlineStart(_ start: InlineStart) {
        inlineStarts.append(start)
    }

    /// Adds an emphasis-like delimiter; a delimiter already registered for the character is kept.
    public func addEmphasisDelimiter(_ delimiter: EmphasisDelimiter) {
        if !delimiters.contains(where: { $0.character == delimiter.character }) { delimiters.append(delimiter) }
    }

    /// Adds a step run on each parsed document, in registration order. A step registered twice under
    /// the same key runs once, so extensions sharing a step agree on it.
    public func addDocumentProcessor(key: String, _ process: @escaping (Document) -> Void) {
        if !documentProcessors.contains(where: { $0.key == key }) { documentProcessors.append((key, process)) }
    }

    /// Wraps the HTML rendering of nodes of exactly `type`; `original` renders what was there before.
    public func wrapRendering<T: Node>(of type: T.Type, _ wrapper: @escaping (_ node: T, _ renderer: HTMLRenderer, _ original: () -> Void) -> Void) {
        renderingWrappers[ObjectIdentifier(type), default: []].append { node, renderer, original in
            guard let typed = node as? T else {
                original()
                return
            }
            wrapper(typed, renderer, original)
        }
    }

    public func build() -> MarkdownPipeline {
        MarkdownPipeline(self)
    }
}

/// An immutable Markdown dialect: parses text into a document tree and renders trees as HTML.
public struct MarkdownPipeline {
    let blockStarts: [BlockStart]
    let inlineStarts: [InlineStart]
    let inlineTriggers: [Bool]
    let delimiterRules: [EmphasisDelimiter?]
    /// Bytes that end a run of plain text.
    let specialBytes: [Bool]
    let documentProcessors: [(Document) -> Void]
    let renderingWrappers: [ObjectIdentifier: [HTMLRenderer.Wrapper]]

    /// Strict CommonMark.
    public static let commonMark = MarkdownPipelineBuilder().build()

    init(_ builder: MarkdownPipelineBuilder) {
        blockStarts = builder.blockStarts
        inlineStarts = builder.inlineStarts
        documentProcessors = builder.documentProcessors.map(\.process)
        renderingWrappers = builder.renderingWrappers

        var special = [Bool](repeating: false, count: 256)
        for byte in "\n`[]\\!<&".utf8 { special[Int(byte)] = true }
        var triggers = [Bool](repeating: false, count: 256)
        for start in builder.inlineStarts {
            for byte in start.triggerCharacters {
                triggers[Int(byte)] = true
                special[Int(byte)] = true
            }
        }
        var rules = [EmphasisDelimiter?](repeating: nil, count: 256)
        for delimiter in builder.delimiters {
            rules[Int(delimiter.character)] = delimiter
            special[Int(delimiter.character)] = true
        }
        inlineTriggers = triggers
        delimiterRules = rules
        specialBytes = special
    }

    public func parse(_ markdown: String) -> Document {
        let parser = BlockParser(lines: MarkdownPipeline.lines(of: markdown), extensionStarts: blockStarts)
        let document = parser.parse()
        for node in document.descendants {
            if let block = node as? Block, block.containsInlines {
                InlineParser.parseContent(of: block, document: document, pipeline: self)
            }
        }
        for process in documentProcessors { process(document) }
        return document
    }

    public func renderHTML(_ document: Document) -> String {
        let renderer = HTMLRenderer(wrappers: renderingWrappers, capacity: 4096)
        renderer.render(document)
        return renderer.html
    }

    public func renderHTML(_ markdown: String) -> String {
        renderHTML(parse(markdown))
    }

    /// Splits on `\n`, `\r\n` and `\r`; NUL becomes U+FFFD. A final line ending does not start another line.
    static func lines(of markdown: String) -> [[UInt8]] {
        var lines: [[UInt8]] = []
        var current: [UInt8] = []
        var previousWasCarriageReturn = false
        var endedWithLineEnding = false
        for byte in markdown.utf8 {
            endedWithLineEnding = false
            if byte == Byte.newline {
                if !previousWasCarriageReturn {
                    lines.append(current)
                    current = []
                }
                previousWasCarriageReturn = false
                endedWithLineEnding = true
            } else if byte == Byte.carriageReturn {
                lines.append(current)
                current = []
                previousWasCarriageReturn = true
                endedWithLineEnding = true
            } else {
                previousWasCarriageReturn = false
                if byte == 0 {
                    current.append(contentsOf: [0xEF, 0xBF, 0xBD])
                } else {
                    current.append(byte)
                }
            }
        }
        if !endedWithLineEnding, !(current.isEmpty && lines.isEmpty) || !current.isEmpty { lines.append(current) }
        return lines
    }
}

import CommonMark
import MarkdownEditorCore

/// GitHub Flavored Markdown tables (GFM spec 0.29, section 4.10), with column alignment.
public struct TablesPlugin: MarkdownPlugin, DocumentFeatureProbe {
    public static let pluginID = "tables"
    public static let stylesheetPath = "assets/tables.css"

    public init() {}

    public var id: String { Self.pluginID }
    public var name: String { "Tables (GFM)" }
    public var version: PluginVersion { PluginVersion(1, 1, 0) }
    public var previewAssets: [PreviewAsset] { [.stylesheet(Self.stylesheetPath)] }

    public func isUsed(by document: Document) -> Bool {
        document.hasDescendant(ofType: Table.self)
    }

    /// Tried before the thematic break and list starts, so delimiter rows such as `-|-` are seen first.
    public func configurePipeline(_ builder: MarkdownPipelineBuilder) {
        builder.addBlockStart(BlockStart(openingCharacters: Set("|-:".utf8), tryStart: Self.startTable))
    }

    /// Opens a table when a delimiter row follows a paragraph whose last line has the same number of cells
    /// (that line becomes the header; earlier lines stay a paragraph).
    private static func startTable(_ parser: BlockParser, _ container: Block) -> BlockStartResult {
        guard !parser.isIndented, let paragraph = container as? Paragraph,
              let alignments = GFMTableSyntax.parseDelimiterRow(String(decoding: parser.restFromNonspace, as: UTF8.self)) else { return .none }

        var lines = paragraph.rawContent.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: false).map(Array.init)
        if lines.last?.isEmpty == true { lines.removeLast() }
        guard let headerBytes = lines.last else { return .none }
        let header = String(decoding: headerBytes, as: UTF8.self)
        guard GFMTableSyntax.splitCells(header).count == alignments.count else { return .none }

        parser.closeUnmatchedBlocks()
        lines.removeLast()
        let headerLine = parser.lineNumber - 1
        if lines.isEmpty {
            let parent = paragraph.parent as? Block
            paragraph.unlink()
            parser.tip = parent ?? parser.document
        } else {
            paragraph.rawContent = Array(lines.joined(separator: [UInt8(ascii: "\n")])) + [UInt8(ascii: "\n")]
            paragraph.endLine = headerLine - 1
            parser.finalize(paragraph)
        }

        let table = parser.addChild(Table(alignments: alignments, delimiterLine: parser.lineNumber))
        table.startLine = headerLine
        table.addRow(header, line: headerLine, isHeader: true)
        parser.advanceToEndOfLine()
        return .leaf
    }
}

/// A GFM table: a header row followed by zero or more body rows.
final class Table: Block {
    let alignments: [ColumnAlignment]
    private let delimiterLine: Int

    init(alignments: [ColumnAlignment], delimiterLine: Int) {
        self.alignments = alignments
        self.delimiterLine = delimiterLine
    }

    override var acceptsLines: Bool { true }

    /// Rows continue until a blank line or the start of another block.
    override func continuation(_ parser: BlockParser) -> BlockContinuation {
        parser.isBlank || GFMTableSyntax.startsOtherBlock(String(decoding: parser.restOfLine, as: UTF8.self)) ? .notMatched : .matched
    }

    override func addLine(_ parser: BlockParser) {
        guard parser.lineNumber > delimiterLine else { return }
        addRow(String(decoding: parser.restOfLine, as: UTF8.self), line: parser.lineNumber, isHeader: false)
        endLine = parser.lineNumber
    }

    /// Adds a row from a raw source line. GFM: cells beyond the header width are ignored and missing cells
    /// are rendered empty.
    func addRow(_ line: String, line lineNumber: Int, isHeader: Bool) {
        let row = TableRow(isHeader: isHeader)
        row.startLine = lineNumber
        row.endLine = lineNumber
        row.isOpen = false
        let cells = GFMTableSyntax.splitCells(line)
        for index in alignments.indices {
            let cell = TableCell()
            cell.startLine = lineNumber
            cell.endLine = lineNumber
            cell.isOpen = false
            cell.rawContent = Array((index < cells.count ? GFMTableSyntax.unescapePipes(cells[index]) : "").utf8)
            row.appendChild(cell)
        }
        appendChild(row)
    }

    /// Renders as GFM does: `align` attributes, `tbody` only when there are body rows.
    override func writeHTML(to renderer: HTMLRenderer) {
        renderer.ensureLine()
        renderer.write("<table")
        renderer.writeAttributes(of: self)
        renderer.write(">\n")
        var inBody = false
        for case let row as TableRow in children {
            if row.isHeader {
                renderer.write("<thead>\n")
            } else if !inBody {
                renderer.write("<tbody>\n")
                inBody = true
            }
            renderer.write("<tr")
            renderer.writeAttributes(of: row)
            renderer.write(">\n")
            let tag = row.isHeader ? "th" : "td"
            for (index, cell) in row.children.enumerated() {
                renderer.write("<\(tag)")
                if index < alignments.count, let align = alignments[index].htmlValue { renderer.write(" align=\"\(align)\"") }
                renderer.write(">")
                renderer.renderChildren(of: cell)
                renderer.write("</\(tag)>\n")
            }
            renderer.write("</tr>\n")
            if row.isHeader { renderer.write("</thead>\n") }
        }
        if inBody { renderer.write("</tbody>\n") }
        renderer.write("</table>\n")
    }
}

final class TableRow: Block {
    let isHeader: Bool

    init(isHeader: Bool) {
        self.isHeader = isHeader
    }
}

final class TableCell: Block {
    override var containsInlines: Bool { true }
}

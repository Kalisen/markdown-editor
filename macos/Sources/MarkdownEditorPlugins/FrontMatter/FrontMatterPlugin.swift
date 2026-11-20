import CommonMark
import MarkdownEditorCore

/// YAML front matter (`---` … `---` at the start of the document) is shown as a table of its top-level keys,
/// as on GitHub, instead of being rendered as text.
public struct FrontMatterPlugin: MarkdownPlugin, DocumentFeatureProbe {
    public static let pluginID = "front-matter"
    public static let stylesheetPath = "assets/front-matter.css"

    public init() {}

    public var id: String { Self.pluginID }
    public var name: String { "Front matter" }
    public var version: PluginVersion { PluginVersion(1, 0, 0) }
    public var previewAssets: [PreviewAsset] { [.stylesheet(Self.stylesheetPath)] }

    public func isUsed(by document: Document) -> Bool {
        document.hasDescendant(ofType: FrontMatterBlock.self) { !$0.entries.isEmpty }
    }

    public func configurePipeline(_ builder: MarkdownPipelineBuilder) {
        builder.addBlockStart(BlockStart(openingCharacters: [UInt8(ascii: "-")], tryStart: Self.startFrontMatter))
    }

    /// Front matter opens with `---` on the first line and ends at the next `---` or `...` line. As in the
    /// Windows app, it is only recognized when such a line exists after the second line of the document.
    private static func startFrontMatter(_ parser: BlockParser, _ container: Block) -> BlockStartResult {
        guard parser.lineNumber == 0, container is Document, !parser.isIndented, parser.nextNonspace == 0,
              isFence(parser.line, "---") else { return .none }
        func isClosingFence(_ index: Int) -> Bool { isFence(parser.lines[index], "---") || isFence(parser.lines[index], "...") }
        guard parser.lines.indices.dropFirst(2).contains(where: isClosingFence),
              let closingLine = parser.lines.indices.dropFirst().first(where: isClosingFence) else { return .none }

        parser.closeUnmatchedBlocks()
        parser.addChild(FrontMatterBlock(closingLine: closingLine))
        parser.advanceToEndOfLine()
        return .leaf
    }

    /// The marker, optionally followed by spaces or tabs.
    private static func isFence(_ line: [UInt8], _ marker: String) -> Bool {
        let markerBytes = Array(marker.utf8)
        return line.starts(with: markerBytes) && line[markerBytes.count...].allSatisfy { $0 == 0x20 || $0 == 0x09 }
    }
}

final class FrontMatterBlock: Block {
    static let tableClass = "front-matter"

    private let closingLine: Int
    private(set) var entries: [FrontMatterEntry] = []

    init(closingLine: Int) {
        self.closingLine = closingLine
    }

    override var acceptsLines: Bool { true }

    override func continuation(_ parser: BlockParser) -> BlockContinuation {
        guard parser.lineNumber == closingLine else { return .matched }
        endLine = closingLine
        parser.finalize(self)
        return .consumedLine
    }

    override func addLine(_ parser: BlockParser) {
        guard parser.lineNumber > startLine else { return } // the opening fence
        super.addLine(parser)
    }

    override func finalize(_ parser: BlockParser) {
        entries = FrontMatterYAML.parse(String(decoding: rawContent, as: UTF8.self))
        rawContent = []
    }

    override func writeHTML(to renderer: HTMLRenderer) {
        guard !entries.isEmpty else { return }
        renderer.ensureLine()
        renderer.write("<table class=\"\(Self.tableClass)\"")
        renderer.writeAttributes(of: self)
        renderer.write(">\n<thead>\n<tr>\n")
        for entry in entries {
            renderer.write("<th>")
            renderer.writeEscaped(entry.key)
            renderer.write("</th>\n")
        }
        renderer.write("</tr>\n</thead>\n<tbody>\n<tr>\n")
        for entry in entries {
            renderer.write("<td>")
            if entry.isRaw {
                renderer.write("<pre><code>")
                renderer.writeEscaped(entry.values[0])
                renderer.write("</code></pre>")
            } else if entry.values.count == 1 {
                renderer.writeEscaped(entry.values[0])
            } else if entry.values.count > 1 {
                renderer.write("<ul>")
                for value in entry.values {
                    renderer.write("<li>")
                    renderer.writeEscaped(value)
                    renderer.write("</li>")
                }
                renderer.write("</ul>")
            }
            renderer.write("</td>\n")
        }
        renderer.write("</tr>\n</tbody>\n</table>\n")
    }
}

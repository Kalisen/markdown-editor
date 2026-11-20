import CommonMark
import MarkdownEditorCore

/// Footnotes as on GitHub: `[^1]` references, `[^1]: text` definitions, numbered list with back-links.
public struct FootnotesPlugin: MarkdownPlugin, DocumentFeatureProbe {
    public static let pluginID = "footnotes"
    public static let stylesheetPath = "assets/footnotes.css"

    public init() {}

    public var id: String { Self.pluginID }
    public var name: String { "Footnotes" }
    public var version: PluginVersion { PluginVersion(1, 0, 0) }
    public var previewAssets: [PreviewAsset] { [.stylesheet(Self.stylesheetPath)] }

    public func isUsed(by document: Document) -> Bool {
        document.hasDescendant(ofType: FootnoteGroup.self)
    }

    public func configurePipeline(_ builder: MarkdownPipelineBuilder) {
        builder.addBlockStart(BlockStart(openingCharacters: [UInt8(ascii: "[")], tryStart: Self.startDefinition))
        builder.addInlineStart(InlineStart(triggerCharacters: [UInt8(ascii: "[")], tryParse: Self.parseReference))
        builder.addDocumentProcessor(key: Self.pluginID, Self.groupFootnotes)
    }

    private static let registryKey = "footnotes.registry"

    /// Footnote definitions by label, and the order in which footnotes are first referenced.
    private final class Registry {
        var definitions: [String: FootnoteDefinition] = [:]
        var referenced: [FootnoteDefinition] = []
    }

    private static func registry(of document: Document) -> Registry {
        if let registry = document.userData[registryKey] as? Registry { return registry }
        let registry = Registry()
        document.userData[registryKey] = registry
        return registry
    }

    /// `[^label]:` at the start of a line opens a definition; its content continues on lines indented by 4.
    private static func startDefinition(_ parser: BlockParser, _ container: Block) -> BlockStartResult {
        guard !parser.isIndented else { return .none }
        let rest = parser.restFromNonspace
        guard rest.count >= 5, rest[1] == UInt8(ascii: "^"), let close = rest.firstIndex(of: UInt8(ascii: "]")), close > 2,
              close + 1 < rest.count, rest[close + 1] == UInt8(ascii: ":"),
              !rest[2..<close].contains(where: { $0 == 0x20 || $0 == 0x09 || $0 == UInt8(ascii: "[") }) else { return .none }
        let label = String(decoding: rest[2..<close], as: UTF8.self)

        parser.closeUnmatchedBlocks()
        parser.advanceNextNonspace()
        parser.advanceOffset(close + 2, columns: false)
        let definition = parser.addChild(FootnoteDefinition(label: label))
        let registry = registry(of: parser.document)
        if registry.definitions[label] == nil { registry.definitions[label] = definition }
        return .container
    }

    /// `[^label]` refers to a defined footnote; with no definition it stays text.
    private static func parseReference(_ parser: InlineParser) -> Bool {
        guard parser.peek(1) == UInt8(ascii: "^") else { return false }
        var end = parser.position + 2
        while let byte = parser.peek(end - parser.position), byte != UInt8(ascii: "]") {
            if byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == UInt8(ascii: "[") { return false }
            end += 1
        }
        guard end > parser.position + 2, parser.peek(end - parser.position) == UInt8(ascii: "]") else { return false }
        let registry = registry(of: parser.document)
        guard let definition = registry.definitions[parser.text((parser.position + 2)..<end)] else { return false }

        if definition.references.isEmpty { registry.referenced.append(definition) }
        let reference = FootnoteReference(definition: definition)
        definition.references.append(reference)
        parser.append(reference)
        parser.position = end + 1
        return true
    }

    /// Moves the referenced footnotes to a numbered group at the end of the document, each ending with links
    /// back to its references. Footnotes that are never referenced are dropped.
    private static func groupFootnotes(in document: Document) {
        let registry = registry(of: document)
        for definition in document.descendants(ofType: FootnoteDefinition.self) { definition.unlink() }
        guard !registry.referenced.isEmpty else { return }

        let group = FootnoteGroup()
        var referenceIndex = 0
        for (offset, definition) in registry.referenced.enumerated() {
            definition.order = offset + 1
            let backReferences = definition.references.map { reference -> FootnoteBackReference in
                referenceIndex += 1
                reference.index = referenceIndex
                return FootnoteBackReference(referenceIndex: referenceIndex)
            }
            let lastParagraph = definition.lastChild as? Paragraph ?? {
                let paragraph = Paragraph()
                paragraph.startLine = definition.lastContentLine
                paragraph.endLine = definition.lastContentLine
                definition.appendChild(paragraph)
                return paragraph
            }()
            backReferences.forEach(lastParagraph.appendChild)
            group.appendChild(definition)
        }
        group.startLine = registry.referenced.map(\.startLine).min() ?? 0
        group.endLine = group.startLine
        document.appendChild(group)
    }
}

/// The content of a footnote. Rendered inside the `FootnoteGroup`.
final class FootnoteDefinition: Block {
    static let continuationIndent = 4

    let label: String
    /// 1-based number, in order of first reference.
    var order = 0
    var references: [FootnoteReference] = []

    init(label: String) {
        self.label = label
    }

    override func canContain(_ child: Block) -> Bool { !(child is ListItem) }

    override func continuation(_ parser: BlockParser) -> BlockContinuation {
        if parser.isBlank {
            guard firstChild != nil else { return .notMatched }
            parser.advanceNextNonspace()
        } else if parser.indent >= Self.continuationIndent {
            parser.advanceOffset(Self.continuationIndent, columns: true)
        } else {
            return .notMatched
        }
        return .matched
    }

    override func writeHTML(to renderer: HTMLRenderer) {
        renderer.ensureLine()
        renderer.write("<li id=\"fn:\(order)\">\n")
        renderer.renderChildren(of: self)
        renderer.ensureLine()
        renderer.write("</li>\n")
    }
}

final class FootnoteGroup: Block {
    override func writeHTML(to renderer: HTMLRenderer) {
        renderer.ensureLine()
        renderer.write("<div class=\"footnotes\">\n<hr />\n<ol>\n")
        renderer.renderChildren(of: self)
        renderer.write("</ol>\n</div>\n")
    }
}

final class FootnoteReference: Inline {
    unowned let definition: FootnoteDefinition
    /// 1-based number of this reference among all footnote references, in footnote order.
    var index = 0

    init(definition: FootnoteDefinition) {
        self.definition = definition
    }

    override func writeHTML(to renderer: HTMLRenderer) {
        guard !renderer.isWritingPlainText else { return }
        renderer.write("<a id=\"fnref:\(index)\" href=\"#fn:\(definition.order)\" class=\"footnote-ref\"><sup>\(definition.order)</sup></a>")
    }

    override var plainText: String { "" }
}

final class FootnoteBackReference: Inline {
    let referenceIndex: Int

    init(referenceIndex: Int) {
        self.referenceIndex = referenceIndex
    }

    override func writeHTML(to renderer: HTMLRenderer) {
        guard !renderer.isWritingPlainText else { return }
        renderer.write("<a href=\"#fnref:\(referenceIndex)\" class=\"footnote-back-ref\">&#8617;</a>")
    }

    override var plainText: String { "" }
}

import CommonMark
import MarkdownEditorCore

/// Table of contents: a line containing only `[TOC]` or `[[_TOC_]]` renders as a nested list of links to the
/// document's headings.
public struct TocPlugin: MarkdownPlugin, DocumentFeatureProbe {
    public static let pluginID = "toc"
    public static let stylesheetPath = "assets/toc.css"
    static let markers = ["[toc]", "[[_toc_]]"]

    public init() {}

    public var id: String { Self.pluginID }
    public var name: String { "Table of contents" }
    public var version: PluginVersion { PluginVersion(1, 0, 0) }
    public var previewAssets: [PreviewAsset] { [.stylesheet(Self.stylesheetPath)] }

    public func isUsed(by document: Document) -> Bool {
        document.hasDescendant(ofType: TocBlock.self)
    }

    public func configurePipeline(_ builder: MarkdownPipelineBuilder) {
        // Same id algorithm as the heading-anchors plugin, so both agree.
        HeadingIdentifiers.register(in: builder)
        builder.addBlockStart(BlockStart(openingCharacters: [UInt8(ascii: "[")], tryStart: Self.startToc))
    }

    /// A marker line inside a paragraph is paragraph text (GitLab/Typora behaviour).
    private static func startToc(_ parser: BlockParser, _ container: Block) -> BlockStartResult {
        guard !parser.isIndented, !(parser.tip is Paragraph) else { return .none }
        let line = String(decoding: parser.restFromNonspace, as: UTF8.self).trimmingCharacters(in: .whitespaces).lowercased()
        guard markers.contains(line) else { return .none }
        parser.closeUnmatchedBlocks()
        parser.addChild(TocBlock())
        parser.advanceToEndOfLine()
        return .leaf
    }
}

/// Placeholder for the table of contents; headings are collected at render time.
final class TocBlock: Block {
    static let navClass = "table-of-contents"

    struct Entry {
        let level: Int
        let id: String
        let text: String
    }

    /// Renders the headings of the whole document as nested lists (relative levels, like GitLab).
    override func writeHTML(to renderer: HTMLRenderer) {
        let entries = root.descendants(ofType: Heading.self).compactMap { heading -> Entry? in
            guard let id = heading.attributes.id, !id.isEmpty else { return nil }
            return Entry(level: heading.level, id: id, text: HeadingIdentifiers.text(of: heading, lineBreak: " ").trimmingCharacters(in: .whitespaces))
        }
        renderer.ensureLine()
        renderer.write("<nav class=\"\(Self.navClass)\"")
        renderer.writeAttributes(of: self)
        renderer.write(">\n")
        renderer.write(Self.buildList(entries))
        renderer.write("</nav>\n")
    }

    static func buildList(_ entries: [Entry]) -> String {
        var html = ""
        var open: [Int] = []
        for entry in entries {
            if open.isEmpty || entry.level > open[open.count - 1] {
                html += "<ul>\n"
                open.append(entry.level)
            } else {
                html += "</li>\n"
                while open.count > 1, entry.level < open[open.count - 1] {
                    open.removeLast()
                    html += "</ul>\n</li>\n"
                }
            }
            html += "<li><a href=\"#\(HTMLEscaping.escape(entry.id))\">\(HTMLEscaping.escape(entry.text))</a>"
        }
        if !open.isEmpty { html += "</li>\n" }
        while !open.isEmpty {
            open.removeLast()
            html += "</ul>\n"
            if !open.isEmpty { html += "</li>\n" }
        }
        return html
    }
}

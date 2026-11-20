import CommonMark
import MarkdownEditorCore

/// Obsidian-style wikilinks: `[[Note]]`, `[[folder/Note|alias]]`, `[[Note#Heading]]` link to `Note.md`;
/// the editor opens them like any other link to a Markdown file.
public struct WikiLinksPlugin: MarkdownPlugin, DocumentFeatureProbe {
    public static let pluginID = "wikilinks"
    public static let stylesheetPath = "assets/wikilinks.css"
    public static let cssClass = "wikilink"

    private static let openBracket = UInt8(ascii: "[")
    private static let closeBracket = UInt8(ascii: "]")

    public init() {}

    public var id: String { Self.pluginID }
    public var name: String { "Wikilinks" }
    public var version: PluginVersion { PluginVersion(1, 0, 0) }
    public var previewAssets: [PreviewAsset] { [.stylesheet(Self.stylesheetPath)] }

    public func isUsed(by document: Document) -> Bool {
        document.hasDescendant(ofType: Link.self) { $0.attributes.classes.contains(Self.cssClass) }
    }

    /// Tried before the standard link rules, which would otherwise consume the outer `[`.
    public func configurePipeline(_ builder: MarkdownPipelineBuilder) {
        builder.addInlineStart(InlineStart(triggerCharacters: [Self.openBracket], tryParse: Self.parseWikiLink))
    }

    /// Parses `[[target#heading|alias]]` into a link carrying the `wikilink` class.
    private static func parseWikiLink(_ parser: InlineParser) -> Bool {
        guard parser.peek(1) == openBracket else { return false }
        let innerStart = parser.position + 2
        var end = innerStart
        while let byte = parser.peek(end - parser.position) {
            if byte == closeBracket, parser.peek(end - parser.position + 1) == closeBracket { break }
            if byte == 0x0A || byte == openBracket { return false }
            end += 1
        }
        guard end > innerStart, parser.peek(end - parser.position) == closeBracket,
              let target = WikiLinkTarget(parser.text(innerStart..<end)) else { return false }

        let link = Link(destination: target.url)
        link.attributes.addClass(cssClass)
        link.appendChild(Text(target.label))
        parser.append(link)
        parser.position = end + 2
        return true
    }
}

/// The parts of a wikilink and the relative URL it points to.
public struct WikiLinkTarget: Equatable {
    public static let markdownExtension = ".md"

    public let note: String
    public let heading: String?
    public let label: String
    public let url: String

    public init?(_ inner: String) {
        let parts = inner.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        let alias = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
        let reference = parts[0].split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        let note = reference[0].trimmingCharacters(in: .whitespaces)
        let heading = reference.count > 1 ? reference[1].trimmingCharacters(in: .whitespaces) : ""
        guard !note.isEmpty else { return nil }

        self.note = note
        self.heading = heading.isEmpty ? nil : heading
        label = !alias.isEmpty ? alias : heading.isEmpty ? note : "\(note) > \(heading)"
        let file = Self.hasExtension(note) ? note : note + Self.markdownExtension
        url = file.replacingOccurrences(of: "\\", with: "/")
    }

    /// True when the last path segment has a period followed by at least one character.
    private static func hasExtension(_ path: String) -> Bool {
        let name = path.split(omittingEmptySubsequences: false) { $0 == "/" || $0 == "\\" }.last ?? ""
        guard let period = name.lastIndex(of: ".") else { return false }
        return name.index(after: period) != name.endIndex
    }
}

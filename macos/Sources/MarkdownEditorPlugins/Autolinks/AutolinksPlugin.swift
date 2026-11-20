import CommonMark
import MarkdownEditorCore

/// GFM extended autolinks: bare `www.`, `http(s)://` URLs and email addresses become links.
public struct AutolinksPlugin: MarkdownPlugin, DocumentFeatureProbe {
    public static let pluginID = "autolinks"

    /// Document data flag set when a bare URL was linked (used to report the plugin as in use).
    private static let linkedKey = "autolinks.linked"

    public init() {}

    public var id: String { Self.pluginID }
    public var name: String { "Autolinks (GFM)" }
    public var version: PluginVersion { PluginVersion(1, 0, 0) }
    public var previewAssets: [PreviewAsset] { [] }

    public func isUsed(by document: Document) -> Bool {
        document.userData[Self.linkedKey] as? Bool == true
    }

    public func configurePipeline(_ builder: MarkdownPipelineBuilder) {
        builder.addDocumentProcessor(key: Self.pluginID, Self.linkBareURLs)
    }

    /// Runs after inline parsing: scans plain text (never inside links, images, code or raw HTML) and
    /// replaces matches with autolinks.
    static func linkBareURLs(in document: Document) {
        for text in document.descendants(ofType: Text.self) where type(of: text) == Text.self && !isInsideLink(text) {
            let matches = GFMAutolinkScanner.scan(text.literal, startsAtBoundary: !(text.previous is Text))
            guard !matches.isEmpty else { continue }

            let scalars = Array(text.literal.unicodeScalars)
            var position = 0
            for match in matches {
                if match.start > position { text.insertBefore(Text(GFMAutolinkScanner.string(scalars, position..<match.start))) }
                let link = Link(destination: match.url)
                link.appendChild(Text(GFMAutolinkScanner.string(scalars, match.start..<(match.start + match.length))))
                text.insertBefore(link)
                position = match.start + match.length
            }
            if position < scalars.count { text.insertBefore(Text(GFMAutolinkScanner.string(scalars, position..<scalars.count))) }
            text.unlink()
            document.userData[linkedKey] = true
        }
    }

    private static func isInsideLink(_ node: Node) -> Bool {
        var ancestor = node.parent
        while let current = ancestor {
            if current is Link || current is Image { return true }
            ancestor = current.parent
        }
        return false
    }
}

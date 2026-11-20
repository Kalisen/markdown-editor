import CommonMark
import MarkdownEditorCore

/// GFM disallowed raw HTML (spec 0.29, section 6.11): in raw HTML, the leading `<` of title, textarea, style,
/// xmp, iframe, noembed, noframes, script and plaintext tags is escaped.
public struct TagFilterPlugin: MarkdownPlugin, DocumentFeatureProbe {
    public static let pluginID = "tag-filter"

    /// Document data flag set when a disallowed tag was escaped (used to report the plugin as in use).
    private static let filteredKey = "tag-filter.filtered"

    public init() {}

    public var id: String { Self.pluginID }
    public var name: String { "Disallowed raw HTML (GFM)" }
    public var version: PluginVersion { PluginVersion(1, 0, 0) }
    public var previewAssets: [PreviewAsset] { [] }

    public func isUsed(by document: Document) -> Bool {
        document.userData[Self.filteredKey] as? Bool == true
    }

    public func configurePipeline(_ builder: MarkdownPipelineBuilder) {
        builder.addDocumentProcessor(key: Self.pluginID, Self.escapeDisallowedTags)
    }

    static func filter(_ html: String) -> String {
        html.replacing(
            #/<(?=\/?(?:title|textarea|style|xmp|iframe|noembed|noframes|script|plaintext)(?:[\s\/>]|$))/#.ignoresCase(),
            with: "&lt;")
    }

    private static func escapeDisallowedTags(in document: Document) {
        for node in document.descendants {
            if let block = node as? HTMLBlock {
                let filtered = filter(block.literal)
                guard filtered != block.literal else { continue }
                block.literal = filtered
            } else if let inline = node as? HTMLInline {
                let filtered = filter(inline.literal)
                guard filtered != inline.literal else { continue }
                inline.literal = filtered
            } else {
                continue
            }
            document.userData[filteredKey] = true
        }
    }
}

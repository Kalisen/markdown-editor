import CommonMark
import MarkdownEditorCore

/// GitHub alerts: blockquotes starting with `[!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]`, `[!CAUTION]`.
public struct AlertsPlugin: MarkdownPlugin, DocumentFeatureProbe {
    public static let pluginID = "alerts"
    public static let stylesheetPath = "assets/alerts.css"

    public init() {}

    public var id: String { Self.pluginID }
    public var name: String { "Alerts" }
    public var version: PluginVersion { PluginVersion(1, 0, 0) }
    public var previewAssets: [PreviewAsset] { [.stylesheet(Self.stylesheetPath)] }

    public func isUsed(by document: Document) -> Bool {
        document.hasDescendant(ofType: Alert.self)
    }

    public func configurePipeline(_ builder: MarkdownPipelineBuilder) {
        builder.addDocumentProcessor(key: Self.pluginID, Self.convertAlerts)
    }

    /// A top-level blockquote whose first line is only `[!KIND]` becomes an alert; the marker line is removed.
    static func convertAlerts(in document: Document) {
        for quote in document.children.compactMap({ $0 as? BlockQuote }) {
            guard let paragraph = quote.firstChild as? Paragraph, let marker = paragraph.firstChild as? Text,
                  type(of: marker) == Text.self, let kind = kind(ofMarker: marker.literal) else { continue }
            let following = marker.next
            guard following == nil || following is SoftBreak || following is LineBreak else { continue }
            following?.unlink()
            marker.unlink()

            let alert = Alert(kind: kind)
            alert.startLine = quote.startLine
            alert.endLine = quote.lastContentLine
            quote.moveChildren(to: alert)
            quote.replace(with: alert)
        }
    }

    private static func kind(ofMarker text: String) -> AlertKind? {
        guard text.hasPrefix("[!"), text.hasSuffix("]") else { return nil }
        return AlertKind(rawValue: text.dropFirst(2).dropLast().lowercased())
    }
}

/// An alert box: a title with an icon, then the content of the blockquote.
final class Alert: Block {
    let kind: AlertKind

    init(kind: AlertKind) {
        self.kind = kind
        super.init()
        attributes.addClass("markdown-alert")
        attributes.addClass("markdown-alert-\(kind.rawValue)")
    }

    override func writeHTML(to renderer: HTMLRenderer) {
        renderer.ensureLine()
        renderer.write("<div")
        renderer.writeAttributes(of: self)
        renderer.write(">\n<p class=\"markdown-alert-title\">\(kind.iconSVG)\(kind.title)</p>\n")
        renderer.renderChildren(of: self)
        renderer.ensureLine()
        renderer.write("</div>\n")
    }
}

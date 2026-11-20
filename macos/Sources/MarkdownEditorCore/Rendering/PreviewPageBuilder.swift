import CommonMark
import Foundation

/// The preview shell page, served from `PreviewOrigins.appOrigin`.
public struct PreviewPage {
    public let html: String
}

/// Builds the preview shell page: base styles, the host script, plugin assets and the Content-Security-Policy.
public enum PreviewPageBuilder {
    public static let contentElementID = "content"
    public static let pageFileName = "index.html"
    public static let scriptFileName = "preview.js"
    public static let styleFileName = "preview.css"

    /// Document content is untrusted (CommonMark allows raw HTML): only the app and plugin origins may supply
    /// script, no inline script/eval, no network access, frames, plugins, forms or base override.
    /// Inline styles are allowed (Mermaid SVGs embed them); images may come from the document folder or https.
    public static func contentSecurityPolicy(pluginIDs: [String]) -> String {
        let pluginOrigins = pluginIDs.map { "\(PreviewOrigins.scheme)://\(PreviewOrigins.pluginHost($0))" }.joined(separator: " ")
        let appOrigin = "\(PreviewOrigins.scheme)://\(PreviewOrigins.appHost)"
        let documentOrigin = "\(PreviewOrigins.scheme)://\(PreviewOrigins.documentHost)"
        func sources(_ parts: String...) -> String { parts.filter { !$0.isEmpty }.joined(separator: " ") }
        return [
            "default-src 'none'",
            // 'wasm-unsafe-eval' lets bundled plugins compile WebAssembly (Graphviz); it does not allow eval or inline script.
            sources("script-src", appOrigin, pluginOrigins, "'wasm-unsafe-eval'"),
            sources("style-src", appOrigin, pluginOrigins, "'unsafe-inline'"),
            sources("font-src", pluginOrigins, "data:"),
            sources("img-src", documentOrigin, "https:", "data:"),
            "connect-src 'none'",
            "frame-src 'none'",
            "object-src 'none'",
            "base-uri 'none'",
            "form-action 'none'",
        ].joined(separator: "; ")
    }

    public static func build(theme: PreviewTheme, plugins: [MarkdownPlugin]) -> PreviewPage {
        var head = ""
        var scripts = ""
        for plugin in plugins {
            for asset in plugin.previewAssets {
                let path = String(asset.relativePath.drop { $0 == "/" })
                let url = HTMLEscaping.escape(PreviewOrigins.pluginOrigin(plugin.id) + path)
                switch asset.kind {
                case .stylesheet: head += "<link rel=\"stylesheet\" href=\"\(url)\">\n"
                case .script: scripts += "<script src=\"\(url)\"></script>\n"
                }
            }
        }
        let policy = contentSecurityPolicy(pluginIDs: plugins.map(\.id))
        return PreviewPage(html: """
            <!DOCTYPE html>
            <html data-theme="\(theme.rawValue)">
            <head>
            <meta charset="utf-8">
            <meta http-equiv="Content-Security-Policy" content="\(policy)">
            <link rel="stylesheet" href="\(styleFileName)">
            \(head)</head>
            <body>
            <main id="\(contentElementID)" class="markdown-body"></main>
            <script src="\(scriptFileName)"></script>
            \(scripts)</body>
            </html>
            """)
    }
}

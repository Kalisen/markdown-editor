import CommonMark
import Foundation

/// The rendered preview as reported by the page: content HTML and the stylesheet URLs in use.
public struct PreviewSnapshot: Equatable {
    public let contentHTML: String
    public let stylesheetURLs: [String]

    public init(contentHTML: String, stylesheetURLs: [String]) {
        self.contentHTML = contentHTML
        self.stylesheetURLs = stylesheetURLs
    }
}

/// Builds a single, script-free HTML file from a preview snapshot with its stylesheets inlined.
/// Pictures of the document folder are referenced by their path relative to the document, so the export
/// shows them when saved beside the document.
public enum HTMLExportBuilder {
    /// - Parameter readStylesheet: returns the CSS text for a stylesheet URL, or nil if it cannot be resolved.
    public static func build(title: String, snapshot: PreviewSnapshot, theme: PreviewTheme, readStylesheet: (String) -> String?) -> String {
        var styles = ""
        var seen = Set<String>()
        for url in snapshot.stylesheetURLs where seen.insert(url).inserted {
            guard let css = readStylesheet(url) else { continue }
            styles += "<style>/* \(HTMLEscaping.escape(url)) */\n\(css.replacingOccurrences(of: "</style", with: "<\\/style"))\n</style>\n"
        }
        return """
            <!DOCTYPE html>
            <html data-theme="\(theme.rawValue)">
            <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>\(HTMLEscaping.escape(title))</title>
            \(styles)</head>
            <body>
            <main id="\(PreviewPageBuilder.contentElementID)" class="markdown-body">
            \(snapshot.contentHTML.replacingOccurrences(of: "=\"\(PreviewOrigins.documentOrigin)", with: "=\""))
            </main>
            </body>
            </html>
            """
    }
}

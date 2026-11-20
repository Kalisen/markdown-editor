import Foundation
import MarkdownEditorCore
import WebKit

/// Serves the preview's `mdeditor://` URLs from `PreviewResources`.
final class PreviewSchemeHandler: NSObject, WKURLSchemeHandler {
    private static let logger = Diagnostics.logger(category: "Preview")

    /// Returns what a URL serves; nil for URLs that are not served.
    var resolve: (URL) -> PreviewResource? = { _ in nil }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url, let resource = resolve(url) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let data: Data
        let mimeType: String
        switch resource {
        case .content(let content, let type):
            data = content
            mimeType = type
        case .file(let file):
            do {
                data = try Data(contentsOf: file)
            } catch {
                // E.g. an image the document refers to but that does not exist: the page shows it as broken.
                Self.logger.debug("Preview file not served \(file.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
                return
            }
            mimeType = PreviewResources.mimeType(of: file)
        }
        let headers = [
            "Content-Type": mimeType.hasPrefix("text/") ? "\(mimeType); charset=utf-8" : mimeType,
            "Content-Length": String(data.count),
            // Plugin fonts and scripts are fetched from the shell page's origin.
            "Access-Control-Allow-Origin": "*",
            "Cache-Control": "no-store",
        ]
        guard let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers) else {
            urlSchemeTask.didFailWithError(URLError(.badServerResponse))
            return
        }
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // Responses are delivered synchronously: there is nothing to cancel.
    }
}

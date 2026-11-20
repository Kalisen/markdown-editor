import Foundation

public enum LinkAction: Equatable {
    case ignore
    /// Open the absolute URL outside the app.
    case openExternal(URL)
    /// Open the Markdown file in the editor.
    case openDocument(URL)
}

/// Decides what a link clicked in the preview does.
public enum PreviewLinkPolicy {
    private static let externalSchemes: Set<String> = ["http", "https", "mailto"]

    /// - Parameter href: the link's href attribute as written in the document (may be relative).
    public static func classify(_ href: String?, documentFolder: URL?) -> LinkAction {
        guard let href, !href.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !href.hasPrefix("#") else { return .ignore }
        guard let scheme = scheme(of: href) else {
            let path = href.prefix { $0 != "?" && $0 != "#" }
            return resolveDocument(String(path), documentFolder: documentFolder)
        }
        if scheme == PreviewOrigins.scheme {
            guard let components = URLComponents(string: href), components.host?.lowercased() == PreviewOrigins.documentHost else { return .ignore }
            return resolveDocument(components.percentEncodedPath, documentFolder: documentFolder)
        }
        guard externalSchemes.contains(scheme), let url = URL(string: href) else { return .ignore }
        return .openExternal(url)
    }

    /// The lowercased URL scheme of an absolute reference, or nil for a relative one.
    private static func scheme(of href: String) -> String? {
        guard let match = href.firstMatch(of: #/^([A-Za-z][A-Za-z0-9+.\-]*):/#) else { return nil }
        return match.1.lowercased()
    }

    /// Markdown files relative to the document folder (parent folders allowed) open in the editor.
    private static func resolveDocument(_ relativePath: String, documentFolder: URL?) -> LinkAction {
        guard let documentFolder, let decoded = relativePath.removingPercentEncoding else { return .ignore }
        let relative = String(decoded.drop { $0 == "/" })
        guard !relative.isEmpty else { return .ignore }
        let file = documentFolder.appendingPathComponent(relative).standardizedFileURL
        return DocumentFileTypes.isMarkdown(file) ? .openDocument(file) : .ignore
    }
}

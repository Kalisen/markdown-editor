import Foundation

/// File types the editor opens and saves.
public enum DocumentFileTypes {
    public static let defaultExtension = "md"

    /// Lowercase, without the dot.
    public static let markdownExtensions = ["md", "markdown", "mdown", "mkd"]

    public static func isMarkdown(_ url: URL) -> Bool {
        markdownExtensions.contains(url.pathExtension.lowercased())
    }
}

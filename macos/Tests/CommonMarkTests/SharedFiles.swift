import Foundation

/// Files shared with the Windows app, at the repository root.
enum SharedFiles {
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("shared")

    static let spec = root.appendingPathComponent("spec")
}

enum SpecHTML {
    /// Like the specification's reference harness, ignores newlines between adjacent tags.
    static func normalize(_ html: String) -> String {
        html.replacingOccurrences(of: ">\n+<", with: "><", options: .regularExpression)
    }
}

import Foundation

/// Files shared with the Windows app, at the repository root.
public enum SharedFiles {
    public static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("shared")

    public static let spec = root.appendingPathComponent("spec")
    public static let preview = root.appendingPathComponent("preview")
    public static let plugins = root.appendingPathComponent("plugins")

    /// A file of a plugin, by its path relative to the plugin folder (e.g. "assets/images.css").
    public static func pluginFile(_ pluginID: String, _ relativePath: String) -> URL {
        plugins.appendingPathComponent(pluginID).appendingPathComponent(relativePath)
    }
}

public enum SpecHTML {
    /// Like the specification's reference harness, ignores newlines between adjacent tags.
    public static func normalize(_ html: String) -> String {
        html.replacingOccurrences(of: ">\n+<", with: "><", options: .regularExpression)
    }
}

/// An extension example of the GitHub Flavored Markdown spec 0.29 (shared/spec/gfm-0.29-extensions.json).
public struct GFMSpecExample: Decodable, CustomStringConvertible, Sendable {
    public let `extension`: String
    public let example: Int
    public let markdown: String
    public let html: String

    public var description: String { "GFM #\(example) (\(`extension`))" }

    public static func examples(for extensionName: String) -> [GFMSpecExample] {
        let data = try! Data(contentsOf: SharedFiles.spec.appendingPathComponent("gfm-0.29-extensions.json"))
        return try! JSONDecoder().decode([GFMSpecExample].self, from: data).filter { $0.extension == extensionName }
    }
}

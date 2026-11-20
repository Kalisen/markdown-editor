import CommonMark

/// Contract implemented by every editor extension.
public protocol MarkdownPlugin {
    /// Stable identifier; lowercase letters, digits and hyphens (see `PluginID`).
    var id: String { get }

    var name: String { get }

    var version: PluginVersion { get }

    /// Adds parser/renderer extensions to the Markdown pipeline. A plugin that throws is skipped and reported.
    func configurePipeline(_ builder: MarkdownPipelineBuilder) throws

    /// Scripts and stylesheets injected into the preview page.
    var previewAssets: [PreviewAsset] { get }
}

/// Optional contract for a `MarkdownPlugin`: reports whether the plugin applies to a parsed document
/// (e.g. the document contains a table), so the editor can show which extensions are in use.
/// Plugins that do not implement it are never reported as in use.
public protocol DocumentFeatureProbe {
    /// - Parameter document: the document parsed with the full pipeline (all plugins' extensions).
    func isUsed(by document: Document) -> Bool
}

public struct PluginVersion: Equatable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(_ major: Int, _ minor: Int, _ patch: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public var description: String { "\(major).\(minor).\(patch)" }
}

/// Validation rules for plugin identifiers (they are used as preview host names).
public enum PluginID {
    public static let maxLength = 40

    public static func isValid(_ id: String) -> Bool {
        !id.isEmpty && id.count <= maxLength && id.wholeMatch(of: #/[a-z0-9]+(-[a-z0-9]+)*/#) != nil
    }
}

public enum PreviewAssetKind {
    /// JavaScript file.
    case script
    /// CSS file.
    case stylesheet
}

/// A file injected into the preview page; `relativePath` is relative to the plugin folder, with `/` separators.
public struct PreviewAsset: Equatable {
    public let kind: PreviewAssetKind
    public let relativePath: String

    public static func script(_ relativePath: String) -> PreviewAsset { PreviewAsset(kind: .script, relativePath: relativePath) }

    public static func stylesheet(_ relativePath: String) -> PreviewAsset { PreviewAsset(kind: .stylesheet, relativePath: relativePath) }
}

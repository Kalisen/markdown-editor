import Foundation

/// Status bar wording for the extensions used by the current document.
public enum PluginUsageText {
    public static let label = "Extensions"
    public static let noneText = "none (CommonMark only)"
    public static let separator = " · "

    /// E.g. "Extensions: Math · Tables (GFM)", in alphabetical order.
    public static func describe(_ used: [MarkdownPlugin]) -> String {
        let names = sorted(used).map(\.name)
        return "\(label): \(names.isEmpty ? noneText : names.joined(separator: separator))"
    }

    /// Tooltip: every loaded plugin, marking those in use.
    public static func details(loaded: [MarkdownPlugin], used: [MarkdownPlugin]) -> String {
        let inUse = Set(used.map(\.id))
        return sorted(loaded).map { "\(inUse.contains($0.id) ? "●" : "○") \($0.name)" }.joined(separator: "\n")
    }

    private static func sorted(_ plugins: [MarkdownPlugin]) -> [MarkdownPlugin] {
        plugins.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

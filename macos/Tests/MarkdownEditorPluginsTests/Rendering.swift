import Foundation
import MarkdownEditorCore
import TestSupport

/// Renders Markdown with the given plugins configured, as the app does.
func render(_ markdown: String, with plugins: MarkdownPlugin...) -> String {
    MarkdownRenderer(plugins: plugins).render(markdown)
}

func assetExists(_ plugin: MarkdownPlugin, _ relativePath: String) -> Bool {
    FileManager.default.fileExists(atPath: SharedFiles.pluginFile(plugin.id, relativePath).path)
}

func readAsset(_ plugin: MarkdownPlugin, _ relativePath: String) throws -> String {
    try String(contentsOf: SharedFiles.pluginFile(plugin.id, relativePath), encoding: .utf8)
}

extension String {
    func occurrences(of text: String) -> Int { components(separatedBy: text).count - 1 }
}

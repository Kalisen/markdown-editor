import Foundation

/// Resolves a linked Markdown file. When the exact file does not exist, the first file with the same name
/// under the document's folder tree is used (closest first), like Obsidian's shortest-path wikilinks.
public struct MarkdownFileLocator {
    private let fileExists: (URL) -> Bool
    private let findFiles: (_ root: URL, _ name: String) -> [URL]

    public init(fileExists: @escaping (URL) -> Bool, findFiles: @escaping (URL, String) -> [URL]) {
        self.fileExists = fileExists
        self.findFiles = findFiles
    }

    public init() {
        self.init(fileExists: { FileManager.default.fileExists(atPath: $0.path) }, findFiles: Self.filesNamed)
    }

    /// - Returns: the file to open, or nil when none is found.
    public func locate(_ file: URL, documentFolder: URL?) -> URL? {
        if fileExists(file) { return file }
        guard let documentFolder else { return nil }
        return findFiles(documentFolder, file.lastPathComponent).min { first, second in
            let depths = (first.pathComponents.count, second.pathComponents.count)
            if depths.0 != depths.1 { return depths.0 < depths.1 }
            return first.path.caseInsensitiveCompare(second.path) == .orderedAscending
        }
    }

    /// Files named `name` (ignoring case) under `root`; folders that cannot be read are skipped.
    private static func filesNamed(under root: URL, _ name: String) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }) else { return [] }
        var matches: [URL] = []
        for case let url as URL in enumerator where url.lastPathComponent.caseInsensitiveCompare(name) == .orderedSame {
            if (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true { matches.append(url) }
        }
        return matches
    }
}

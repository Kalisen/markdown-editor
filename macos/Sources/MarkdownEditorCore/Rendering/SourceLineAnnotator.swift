import CommonMark

/// Tags rendered blocks with the 0-based source line range they come from, so the preview can map
/// between editor lines and rendered positions (scroll synchronization). See shared/preview/preview.js.
public enum SourceLineAnnotator {
    /// First source line of the block (0-based).
    public static let startAttribute = "data-line"

    /// Last source line of the block (0-based, inclusive).
    public static let endAttribute = "data-line-end"

    public static func annotate(_ document: Document) {
        for node in document.descendants {
            guard let block = node as? Block else { continue }
            block.attributes.addPropertyIfAbsent(startAttribute, String(block.startLine))
            block.attributes.addPropertyIfAbsent(endAttribute, String(block.lastContentLine))
        }
    }
}

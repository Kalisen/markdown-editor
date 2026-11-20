import CommonMark
import MarkdownEditorCore

/// GFM task list items: `- [ ] todo` / `- [x] done` render as (read-only) checkboxes.
public struct TaskListsPlugin: MarkdownPlugin, DocumentFeatureProbe {
    public static let pluginID = "task-lists"
    public static let stylesheetPath = "assets/task-lists.css"
    static let listClass = "contains-task-list"
    static let itemClass = "task-list-item"

    public init() {}

    public var id: String { Self.pluginID }
    public var name: String { "Task lists (GFM)" }
    public var version: PluginVersion { PluginVersion(1, 0, 0) }
    public var previewAssets: [PreviewAsset] { [.stylesheet(Self.stylesheetPath)] }

    public func isUsed(by document: Document) -> Bool {
        document.hasDescendant(ofType: TaskListMarker.self)
    }

    public func configurePipeline(_ builder: MarkdownPipelineBuilder) {
        builder.addDocumentProcessor(key: Self.pluginID, Self.markTaskItems)
    }

    /// A list item whose text starts with `[ ]`, `[x]` or `[X]`, followed by whitespace or nothing, is a task.
    static func markTaskItems(in document: Document) {
        for item in document.descendants(ofType: ListItem.self) {
            guard let paragraph = item.firstChild as? Paragraph, let text = paragraph.firstChild as? Text,
                  type(of: text) == Text.self else { continue }
            let marker = text.literal.prefix(3)
            guard marker == "[ ]" || marker == "[x]" || marker == "[X]" else { continue }
            let rest = text.literal.dropFirst(3)
            if let following = rest.first {
                guard following == " " || following == "\t" else { continue }
            } else if let next = text.next, !(next is SoftBreak || next is LineBreak) {
                continue
            }

            text.insertBefore(TaskListMarker(isChecked: marker != "[ ]"))
            if rest.isEmpty { text.unlink() } else { text.literal = String(rest) }
            item.attributes.addClass(itemClass)
            (item.parent as? List)?.attributes.addClass(listClass)
        }
    }
}

final class TaskListMarker: Inline {
    let isChecked: Bool

    init(isChecked: Bool) {
        self.isChecked = isChecked
    }

    override func writeHTML(to renderer: HTMLRenderer) {
        guard !renderer.isWritingPlainText else { return }
        renderer.write(isChecked ? "<input disabled=\"disabled\" type=\"checkbox\" checked=\"checked\" />" : "<input disabled=\"disabled\" type=\"checkbox\" />")
    }

    override var plainText: String { "" }
}

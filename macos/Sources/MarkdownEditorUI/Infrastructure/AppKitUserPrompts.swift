import AppKit
import MarkdownEditorCore
import UniformTypeIdentifiers

/// Standard macOS panels and alerts for the editing workflow.
final class AppKitUserPrompts: UserPrompts {
    private static let fileChangedMessage = "The file has changed on the disk."

    private static let markdownTypes: [UTType] = DocumentFileTypes.markdownExtensions.compactMap { UTType(filenameExtension: $0) }

    func askOpenFile() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = Self.markdownTypes + [.plainText]
        panel.allowsOtherFileTypes = true
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    func askSaveFile(suggestedName: String) -> URL? {
        savePanel(suggestedName: suggestedName, types: Array(Self.markdownTypes.prefix(1)))
    }

    func askExportFile(suggestedName: String, format: ExportFormat) -> URL? {
        savePanel(suggestedName: suggestedName, types: [format == .html ? .html : .pdf])
    }

    private func savePanel(suggestedName: String, types: [UTType]) -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = types
        panel.allowsOtherFileTypes = true
        panel.isExtensionHidden = false
        panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }

    func askUnsavedChanges(documentName: String) -> UnsavedChangesDecision {
        let alert = NSAlert()
        alert.messageText = "Do you want to save the changes made to \(documentName)?"
        alert.informativeText = "Your changes will be lost if you don't save them."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let discard = alert.addButton(withTitle: "Don't Save")
        discard.hasDestructiveAction = true
        discard.keyEquivalent = "d"
        discard.keyEquivalentModifierMask = [.command]
        switch alert.runModal() {
        case .alertFirstButtonReturn: return .save
        case .alertThirdButtonReturn: return .discard
        default: return .cancel
        }
    }

    func askReloadChangedFile(hasUnsavedChanges: Bool) -> Bool {
        askReload(message: Self.fileChangedMessage, detail: hasUnsavedChanges ? "Reloading discards your unsaved changes." : "")
    }

    func askReloadDiscardingChanges(documentName: String) -> Bool {
        askReload(message: "Reload \(documentName) and discard your unsaved changes?", detail: "")
    }

    func showError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = message
        alert.runModal()
    }

    private func askReload(message: String, detail: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        alert.addButton(withTitle: "Reload")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}

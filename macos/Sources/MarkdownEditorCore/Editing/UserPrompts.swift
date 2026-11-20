import Foundation

public enum UnsavedChangesDecision {
    case save
    case discard
    case cancel
}

/// User interactions required by the editing workflow (implemented by the UI layer).
public protocol UserPrompts {
    /// - Returns: the chosen file, or nil if cancelled.
    func askOpenFile() -> URL?

    /// - Returns: the chosen file, or nil if cancelled.
    func askSaveFile(suggestedName: String) -> URL?

    /// - Returns: the chosen export file, or nil if cancelled.
    func askExportFile(suggestedName: String, format: ExportFormat) -> URL?

    func askUnsavedChanges(documentName: String) -> UnsavedChangesDecision

    /// Tells the user the file was modified by another program.
    /// - Parameter hasUnsavedChanges: true when reloading would lose edits made in the editor.
    /// - Returns: true to reload the file, false to keep the editor's text.
    func askReloadChangedFile(hasUnsavedChanges: Bool) -> Bool

    /// Confirms a reload the user asked for while the document has unsaved changes.
    /// - Returns: true to reload and lose the changes.
    func askReloadDiscardingChanges(documentName: String) -> Bool

    func showError(_ message: String)
}

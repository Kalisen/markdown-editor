import Foundation

/// Document lifecycle: new / open / save / save-as / reload, guarding unsaved changes and noticing when
/// another program modifies the file. UI-agnostic so the workflow is unit-testable.
public final class EditorSession {
    private static let logger = Diagnostics.logger(category: "Editing")

    private let store: DocumentStore
    private let prompts: UserPrompts
    private let watcher: DocumentWatcher

    /// Operations in progress; a nested one (saving from the unsaved-changes prompt) counts too.
    private var operations = 0

    public private(set) var document = MarkdownDocument()

    /// Called when another document is shown or the document was saved.
    public var onDocumentChanged: (() -> Void)?

    /// Hints that the file may have been modified by another program; answer it by calling
    /// `checkForExternalChange()`. May be called on any thread.
    public var onExternalChangeSuspected: (() -> Void)? {
        get { watcher.onChange }
        set { watcher.onChange = newValue }
    }

    public init(store: DocumentStore, prompts: UserPrompts, watcher: DocumentWatcher) {
        self.store = store
        self.prompts = prompts
        self.watcher = watcher
    }

    @discardableResult
    public func new() -> Bool {
        run {
            guard confirmDiscard() else { return false }
            replace(with: MarkdownDocument())
            return true
        }
    }

    /// - Parameter file: the file to open; nil asks the user.
    @discardableResult
    public func open(_ file: URL? = nil) -> Bool {
        run {
            guard confirmDiscard(), let file = file ?? prompts.askOpenFile() else { return false }
            return load(file)
        }
    }

    /// Re-reads the document from its file, after confirmation if that loses unsaved changes.
    @discardableResult
    public func reload() -> Bool {
        run {
            guard let file = document.fileURL else { return false }
            if document.isDirty, !prompts.askReloadDiscardingChanges(documentName: document.displayName) { return false }
            return load(file)
        }
    }

    /// Offers to reload when the file no longer holds what was last loaded or saved. Declining keeps the
    /// editor's text, now unsaved, and the same file content is not offered again.
    /// - Returns: true when the document was reloaded.
    @discardableResult
    public func checkForExternalChange() -> Bool {
        // Another operation is running (possibly waiting on a prompt): it must not be interleaved with a reload.
        guard operations == 0, let file = document.fileURL else { return false }
        return run {
            let diskText: String
            do {
                diskText = try store.read(file)
            } catch {
                // Deleted, or still being written: the next check picks it up.
                Self.logger.debug("External change check skipped for \(file.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                return false
            }
            guard !document.matchesSaved(diskText) else { return false }

            let hadUnsavedChanges = document.isDirty
            document.markChangedOnDisk(diskText)
            return prompts.askReloadChangedFile(hasUnsavedChanges: hadUnsavedChanges) && load(file)
        }
    }

    @discardableResult
    public func save() -> Bool {
        run {
            guard let file = document.fileURL else { return saveAs() }
            return write(to: file)
        }
    }

    @discardableResult
    public func saveAs() -> Bool {
        run {
            let suggested = document.fileURL?.lastPathComponent ?? "\(MarkdownDocument.untitledName).\(DocumentFileTypes.defaultExtension)"
            guard let file = prompts.askSaveFile(suggestedName: suggested) else { return false }
            return write(to: file)
        }
    }

    /// - Returns: true when it is safe to discard the current document (e.g. on close).
    public func confirmDiscard() -> Bool {
        run {
            guard document.isDirty else { return true }
            switch prompts.askUnsavedChanges(documentName: document.displayName) {
            case .save: return save()
            case .discard: return true
            case .cancel: return false
            }
        }
    }

    private func run(_ operation: () -> Bool) -> Bool {
        operations += 1
        defer { operations -= 1 }
        return operation()
    }

    private func load(_ file: URL) -> Bool {
        do {
            let text = try store.read(file)
            replace(with: MarkdownDocument(fileURL: file.standardizedFileURL, text: text))
            return true
        } catch {
            Self.logger.error("Could not open \(file.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            prompts.showError("Could not open '\(file.path)': \(error.localizedDescription)")
            return false
        }
    }

    private func write(to file: URL) -> Bool {
        do {
            try store.write(document.text, to: file)
            document.markSaved(at: file.standardizedFileURL)
            documentChanged()
            return true
        } catch {
            Self.logger.error("Could not save \(file.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            prompts.showError("Could not save '\(file.path)': \(error.localizedDescription)")
            return false
        }
    }

    private func replace(with document: MarkdownDocument) {
        self.document = document
        documentChanged()
    }

    private func documentChanged() {
        watcher.watch(document.fileURL)
        onDocumentChanged?()
    }
}

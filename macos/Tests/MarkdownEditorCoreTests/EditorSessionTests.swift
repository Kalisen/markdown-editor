import Foundation
import Testing
@testable import MarkdownEditorCore

final class EditorSessionTests {
    private static let fileA = URL(fileURLWithPath: "/docs/a.md")
    private static let fileB = URL(fileURLWithPath: "/docs/b.md")

    private final class MemoryStore: DocumentStore {
        var files: [URL: String] = [:]
        var failWrites = false

        func read(_ url: URL) throws -> String {
            guard let text = files[url] else { throw TestError(message: "missing") }
            return text
        }

        func write(_ text: String, to url: URL) throws {
            if failWrites { throw TestError(message: "disk full") }
            files[url] = text
        }
    }

    private final class ScriptedPrompts: UserPrompts {
        var openFile: URL?
        var saveFile: URL?
        var decision = UnsavedChangesDecision.cancel
        var reload = false
        private(set) var unsavedAsked = 0
        private(set) var suggestedName: String?
        private(set) var errors: [String] = []
        private(set) var changedFileAsked: [Bool] = []
        private(set) var reloadDiscardAsked = 0

        func askOpenFile() -> URL? { openFile }

        func askSaveFile(suggestedName: String) -> URL? {
            self.suggestedName = suggestedName
            return saveFile
        }

        func askExportFile(suggestedName: String, format: ExportFormat) -> URL? { nil }

        func askUnsavedChanges(documentName: String) -> UnsavedChangesDecision {
            unsavedAsked += 1
            return decision
        }

        func askReloadChangedFile(hasUnsavedChanges: Bool) -> Bool {
            changedFileAsked.append(hasUnsavedChanges)
            return reload
        }

        func askReloadDiscardingChanges(documentName: String) -> Bool {
            reloadDiscardAsked += 1
            return reload
        }

        func showError(_ message: String) { errors.append(message) }
    }

    private final class FakeWatcher: DocumentWatcher {
        var onChange: (() -> Void)?
        private(set) var watched: URL?

        func watch(_ file: URL?) { watched = file }
    }

    private let store = MemoryStore()
    private let prompts = ScriptedPrompts()
    private let watcher = FakeWatcher()
    private let session: EditorSession

    init() {
        store.files[Self.fileA] = "# A"
        session = EditorSession(store: store, prompts: prompts, watcher: watcher)
    }

    @Test func openLoadsFileViaPromptAndRaisesChange() {
        var raised = 0
        session.onDocumentChanged = { raised += 1 }
        prompts.openFile = Self.fileA
        #expect(session.open())
        #expect(session.document.fileURL == Self.fileA)
        #expect(session.document.text == "# A")
        #expect(!session.document.isDirty)
        #expect(raised == 1)
    }

    @Test func openCancelledOrFailingKeepsCurrentDocument() {
        let before = session.document
        #expect(!session.open())
        #expect(!session.open(Self.fileB))
        #expect(session.document === before)
        #expect(prompts.errors.count == 1)
    }

    @Test func saveUntitledAsksForPathWithDefaultName() {
        session.document.text = "x"
        prompts.saveFile = Self.fileB
        #expect(session.save())
        #expect(prompts.suggestedName == "Untitled.md")
        #expect(store.files[Self.fileB] == "x")
        #expect(session.document.fileURL == Self.fileB)
        #expect(!session.document.isDirty)
    }

    @Test func saveExistingWritesWithoutPrompt() {
        session.open(Self.fileA)
        session.document.text = "changed"
        #expect(session.save())
        #expect(prompts.suggestedName == nil)
        #expect(store.files[Self.fileA] == "changed")
    }

    @Test func saveFailureReportsErrorAndStaysDirty() {
        session.open(Self.fileA)
        session.document.text = "changed"
        store.failWrites = true
        #expect(!session.save())
        #expect(session.document.isDirty)
        #expect(prompts.errors.count == 1)
    }

    @Test func cleanDocumentIsDiscardedWithoutAsking() {
        #expect(session.new())
        #expect(prompts.unsavedAsked == 0)
    }

    @Test(arguments: [(UnsavedChangesDecision.discard, true, false), (.cancel, false, false), (.save, true, true)])
    func dirtyDocumentDecisionControlsNew(decision: UnsavedChangesDecision, proceeds: Bool, saved: Bool) {
        session.open(Self.fileA)
        session.document.text = "edited"
        prompts.decision = decision
        #expect(session.new() == proceeds)
        #expect((store.files[Self.fileA] == "edited") == saved)
        #expect(session.document.fileURL == (proceeds ? nil : Self.fileA))
    }

    @Test func watcherFollowsTheDocumentFileAndItsHintsAreForwarded() {
        var hints = 0
        session.onExternalChangeSuspected = { hints += 1 }
        session.open(Self.fileA)
        #expect(watcher.watched == Self.fileA)
        prompts.saveFile = Self.fileB
        session.saveAs()
        #expect(watcher.watched == Self.fileB)
        session.new()
        #expect(watcher.watched == nil)
        watcher.onChange?()
        #expect(hints == 1)
    }

    @Test func externalChangeAcceptedReloadsTheFile() {
        session.open(Self.fileA)
        store.files[Self.fileA] = "# external"
        prompts.reload = true
        #expect(session.checkForExternalChange())
        #expect(session.document.text == "# external")
        #expect(!session.document.isDirty)
        #expect(prompts.changedFileAsked == [false])
    }

    @Test func externalChangeDeclinedKeepsTextAsUnsavedAndIsNotOfferedAgain() {
        session.open(Self.fileA)
        store.files[Self.fileA] = "# external"
        #expect(!session.checkForExternalChange())
        #expect(!session.checkForExternalChange())
        #expect(session.document.text == "# A")
        #expect(session.document.isDirty)
        #expect(prompts.changedFileAsked.count == 1)
    }

    @Test func externalChangePromptWarnsAboutUnsavedChanges() {
        session.open(Self.fileA)
        session.document.text = "edited"
        store.files[Self.fileA] = "# external"
        session.checkForExternalChange()
        #expect(prompts.changedFileAsked == [true])
    }

    @Test func ownSaveMissingFileOrUntitledDocumentIsNotAnExternalChange() {
        #expect(!session.checkForExternalChange()) // untitled
        session.open(Self.fileA)
        session.document.text = "changed"
        session.save()
        #expect(!session.checkForExternalChange()) // own save
        store.files[Self.fileA] = nil
        #expect(!session.checkForExternalChange()) // deleted
        #expect(prompts.changedFileAsked.isEmpty)
        #expect(prompts.errors.isEmpty)
    }

    @Test func externalChangeIsNotCheckedWhileAnotherOperationIsRunning() {
        session.open(Self.fileA)
        store.files[Self.fileA] = "# external"
        prompts.reload = true
        var checkedDuringSave = false
        session.onDocumentChanged = { [session] in checkedDuringSave = session.checkForExternalChange() }
        session.document.text = "mine"
        session.save()
        #expect(!checkedDuringSave)
        #expect(session.document.text == "mine")
    }

    @Test func reloadRereadsACleanDocumentWithoutAsking() {
        session.open(Self.fileA)
        store.files[Self.fileA] = "# external"
        #expect(session.reload())
        #expect(session.document.text == "# external")
        #expect(prompts.reloadDiscardAsked == 0)
    }

    @Test(arguments: [(true, "# A"), (false, "edited")])
    func reloadOfDirtyDocumentNeedsConfirmation(confirmed: Bool, expectedText: String) {
        session.open(Self.fileA)
        session.document.text = "edited"
        prompts.reload = confirmed
        #expect(session.reload() == confirmed)
        #expect(session.document.text == expectedText)
    }

    @Test func reloadDoesNothingForUntitledDocumentAndReportsUnreadableFile() {
        #expect(!session.reload())
        #expect(prompts.errors.isEmpty)
        session.open(Self.fileA)
        store.files[Self.fileA] = nil
        #expect(!session.reload())
        #expect(prompts.errors.count == 1)
    }
}

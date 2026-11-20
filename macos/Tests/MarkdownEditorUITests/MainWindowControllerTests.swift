import AppKit
import Foundation
import Testing
import TestSupport
import MarkdownEditorCore
import MarkdownEditorPlugins
@testable import MarkdownEditorUI

/// The editor window wired as in the app, with scripted dialogs and files in a temporary folder.
@MainActor
final class MainWindowControllerTests {
    private static let timeout: TimeInterval = 30

    private final class ScriptedPrompts: UserPrompts {
        var exportFile: URL?
        var saveFile: URL?
        var decision = UnsavedChangesDecision.cancel
        var reload = true
        private(set) var unsavedAsked = 0
        private(set) var changedFileAsked = 0
        private(set) var errors: [String] = []

        func askOpenFile() -> URL? { nil }
        func askSaveFile(suggestedName: String) -> URL? { saveFile }
        func askExportFile(suggestedName: String, format: ExportFormat) -> URL? { exportFile }

        func askUnsavedChanges(documentName: String) -> UnsavedChangesDecision {
            unsavedAsked += 1
            return decision
        }

        func askReloadChangedFile(hasUnsavedChanges: Bool) -> Bool {
            changedFileAsked += 1
            return reload
        }

        func askReloadDiscardingChanges(documentName: String) -> Bool { reload }
        func showError(_ message: String) { errors.append(message) }
    }

    private let folder = FileManager.default.temporaryDirectory.appendingPathComponent("md-window-\(UUID().uuidString)").standardizedFileURL
    private let prompts = ScriptedPrompts()
    private let controller: MainWindowController
    private let file: URL

    init() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        file = folder.appendingPathComponent("doc.md")
        try Data("# Title\n\ntext\n".utf8).write(to: file)
        let catalog = PluginCatalog(bundled: BundledPlugins.all, pluginsFolder: SharedFiles.plugins)
        controller = MainWindowController(
            session: EditorSession(store: FileDocumentStore(), prompts: prompts, watcher: FileDocumentWatcher()), prompts: prompts,
            renderer: MarkdownRenderer(plugins: BundledPlugins.all), plugins: catalog.plugins, failures: [], previewFolder: SharedFiles.preview)
    }

    deinit {
        try? FileManager.default.removeItem(at: folder)
    }

    private func wait(for description: String, sourceLocation: SourceLocation = #_sourceLocation, until condition: () async throws -> Bool) async throws {
        let deadline = Date().addingTimeInterval(Self.timeout)
        while Date() < deadline {
            if try await condition() { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        Issue.record("Timed out waiting for \(description)", sourceLocation: sourceLocation)
    }

    private func previewHolds(_ condition: String) async throws -> Bool {
        try await controller.preview.webView.callAsyncJavaScript("return (\(condition));", arguments: [:], in: nil, contentWorld: .page) as? Bool == true
    }

    private func type(_ text: String) {
        controller.textView.insertText(text, replacementRange: NSRange(location: controller.textView.string.utf16.count, length: 0))
    }

    @Test func newWindowShowsAnUntitledDocumentAndThePluginCount() {
        #expect(controller.window?.title == "Untitled")
        #expect(controller.window?.isDocumentEdited == false)
        #expect(controller.statusBar.pluginsText == "17 plugin(s) loaded")
    }

    @Test func openingAFileShowsItInTheEditorThePreviewAndTheStatusBar() async throws {
        controller.open(file)
        #expect(controller.textView.string == "# Title\n\ntext\n")
        #expect(controller.window?.title == "doc.md")
        #expect(controller.window?.representedURL == file)
        try await wait(for: "the preview") { try await self.previewHolds("document.querySelector('h1#title')?.textContent === 'Title'") }
        try await wait(for: "the status bar") { self.controller.statusBar.extensionsText == "Extensions: Heading anchors" }
        #expect(controller.statusBar.extensionsDetails?.contains("● Heading anchors\n○ Math") == true)
    }

    @Test func typingMarksTheDocumentEditedAndRefreshesThePreviewThenSavingWritesTheFile() async throws {
        controller.open(file)
        type("\n| a |\n| - |\n| typed |\n")
        #expect(controller.window?.isDocumentEdited == true)
        try await wait(for: "the preview") { try await self.previewHolds("document.querySelector('td')?.textContent === 'typed'") }
        try await wait(for: "the status bar") { self.controller.statusBar.extensionsText.contains("Tables (GFM)") }

        controller.saveFile(nil)
        #expect(controller.window?.isDocumentEdited == false)
        #expect(try String(contentsOf: file, encoding: .utf8) == "# Title\n\ntext\n\n| a |\n| - |\n| typed |\n")
        controller.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification))
        #expect(prompts.changedFileAsked == 0, "the app's own save is not an external change")
    }

    @Test func undoRestoresTheSavedStateAndClearsTheEditedMark() async throws {
        controller.open(file)
        type("x")
        controller.textView.undoManager?.undo()
        try await wait(for: "the edited mark to clear") { self.controller.window?.isDocumentEdited == false }
        #expect(controller.textView.string == "# Title\n\ntext\n")
    }

    @Test func fileChangedByAnotherProgramIsReloadedOnceTheWindowIsUsedAgain() async throws {
        controller.open(file)
        controller.textView.setSelectedRange(NSRange(location: 3, length: 0))
        try Data("# Title\n\nchanged elsewhere\n".utf8).write(to: file, options: .atomic)
        controller.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification))
        #expect(prompts.changedFileAsked == 1)
        #expect(controller.textView.string == "# Title\n\nchanged elsewhere\n")
        #expect(controller.textView.selectedRange().location == 3)
        #expect(controller.statusBar.statusText == "Reloaded doc.md")
    }

    @Test func editorAndPreviewFollowEachOthersScrolling() async throws {
        let long = folder.appendingPathComponent("long.md")
        try Data((0..<400).map { "Paragraph \($0)\n" }.joined(separator: "\n").utf8).write(to: long)
        controller.window?.setContentSize(NSSize(width: 1000, height: 500))
        controller.window?.layoutIfNeeded()
        controller.open(long)
        try await wait(for: "the preview") { try await self.previewHolds("document.querySelectorAll('[data-line]').length === 400") }

        // The editor drives: its line 300 goes to the top of both panels.
        controller.textView.layoutManager!.ensureLayout(for: controller.textView.textContainer!)
        controller.textView.sizeToFit()
        let lineStart = controller.textView.lineIndex.start(ofLine: 300)
        let glyph = controller.textView.layoutManager!.glyphIndexForCharacter(at: lineStart)
        let top = controller.textView.layoutManager!.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil).minY + controller.textView.textContainerOrigin.y
        controller.textView.scroll(NSPoint(x: 0, y: top))
        try await wait(for: "the preview to follow") {
            try await self.previewHolds("Math.abs(document.querySelector('[data-line=\"300\"]').getBoundingClientRect().top) < 2")
        }

        // The preview drives: the editor shows the reported line at its top, without sending it back.
        controller.preview.onScrolled?(ScrollPosition(line: 100))
        let expected = controller.textView.layoutManager!.lineFragmentRect(
            forGlyphAt: controller.textView.layoutManager!.glyphIndexForCharacter(at: controller.textView.lineIndex.start(ofLine: 100)), effectiveRange: nil).minY
            + controller.textView.textContainerOrigin.y
        #expect(abs(controller.editorScrollView.contentView.bounds.minY - expected) < 1)
        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(try await previewHolds("Math.abs(document.querySelector('[data-line=\"300\"]').getBoundingClientRect().top) < 2"))
    }

    @Test func exportsHtmlAndPdfFromTheMenuActions() async throws {
        controller.open(file)
        try await wait(for: "the preview") { try await self.previewHolds("!!document.querySelector('h1#title')") }
        let html = folder.appendingPathComponent("out.html")
        prompts.exportFile = html
        controller.exportToHTML(nil)
        try await wait(for: "the HTML export") { self.controller.statusBar.statusText == "Exported to \(html.path)" }
        let exported = try String(contentsOf: html, encoding: .utf8)
        #expect(exported.contains("<title>doc</title>"))
        #expect(exported.contains("<h1 id=\"title\""))

        let pdf = folder.appendingPathComponent("out.pdf")
        prompts.exportFile = pdf
        controller.exportToPDF(nil)
        try await wait(for: "the PDF export") { self.controller.statusBar.statusText == "Exported to \(pdf.path)" }
        #expect(try Data(contentsOf: pdf).prefix(5) == Data("%PDF-".utf8))
        #expect(prompts.errors.isEmpty)
    }

    @Test func closingADocumentWithUnsavedChangesAsksOnceAndCanBeCancelled() {
        controller.open(file)
        type("x")
        #expect(!controller.windowShouldClose(controller.window!))
        #expect(prompts.unsavedAsked == 1)
        prompts.decision = .discard
        #expect(controller.windowShouldClose(controller.window!))
        #expect(controller.confirmClose(), "quitting after the window closed does not ask again")
        #expect(prompts.unsavedAsked == 2)
        #expect(try! String(contentsOf: file, encoding: .utf8) == "# Title\n\ntext\n")
    }

    @Test func reloadIsOnlyAvailableForADocumentWithAFile() {
        let reload = NSMenuItem(title: "Reload File", action: #selector(MainWindowController.reloadFile(_:)), keyEquivalent: "")
        #expect(!controller.validateMenuItem(reload))
        controller.open(file)
        #expect(controller.validateMenuItem(reload))
    }

    @Test func linkToAnotherMarkdownFileOpensItInTheEditor() async throws {
        try Data("# Other\n".utf8).write(to: folder.appendingPathComponent("other.md"))
        try Data("[go](other.md)\n".utf8).write(to: file)
        controller.open(file)
        try await wait(for: "the preview") { try await self.previewHolds("!!document.querySelector('a[href=\"other.md\"]')") }
        _ = try await controller.preview.webView.callAsyncJavaScript("document.querySelector('a').click()", arguments: [:], in: nil, contentWorld: .page)
        try await wait(for: "the linked document") { self.controller.window?.title == "other.md" }
        #expect(controller.textView.string == "# Other\n")
    }
}

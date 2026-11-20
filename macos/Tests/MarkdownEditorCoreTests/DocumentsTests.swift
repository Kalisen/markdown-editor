import Foundation
import Testing
@testable import MarkdownEditorCore

struct MarkdownDocumentTests {
    @Test func newDocumentIsUntitledAndClean() {
        let document = MarkdownDocument()
        #expect(document.displayName == MarkdownDocument.untitledName)
        #expect(!document.isDirty)
        #expect(document.folder == nil)
    }

    @Test func editingMarksDirtyAndRevertingOrSavingCleans() {
        let document = MarkdownDocument(fileURL: URL(fileURLWithPath: "/d/a.md"), text: "x")
        document.text = "y"
        #expect(document.isDirty)
        document.text = "x"
        #expect(!document.isDirty)
        document.text = "z"
        document.markSaved(at: URL(fileURLWithPath: "/e/b.md"))
        #expect(document.displayName == "b.md")
        #expect(document.folder?.path == "/e")
        #expect(!document.isDirty)
    }

    @Test func fileChangedOnDiskMakesDocumentDirtyUntilItMatchesTheFile() {
        let document = MarkdownDocument(fileURL: URL(fileURLWithPath: "/d/a.md"), text: "x")
        #expect(document.matchesSaved("x"))
        document.markChangedOnDisk("y")
        #expect(document.isDirty)
        #expect(document.matchesSaved("y"))
        #expect(!document.matchesSaved("x"))
        document.text = "y"
        #expect(!document.isDirty)
    }

    @Test func sameLengthEditIsDirty() {
        let document = MarkdownDocument(text: "abc")
        document.text = "abd"
        #expect(document.isDirty)
    }
}

final class FileDocumentStoreTests {
    private let file = FileManager.default.temporaryDirectory.appendingPathComponent("md-store-\(UUID().uuidString).md")

    deinit { try? FileManager.default.removeItem(at: file) }

    @Test func writesUTF8WithoutMarkPreservingLineEndingsAndReadsBack() throws {
        let store = FileDocumentStore()
        let text = "é\r\nb\nc"
        try store.write(text, to: file)
        #expect(try Data(contentsOf: file) == Data(text.utf8))
        #expect(try store.read(file) == text)
    }

    @Test(arguments: [String.Encoding.utf16LittleEndian, .utf16BigEndian])
    func readsUTF16FileWithMark(_ encoding: String.Encoding) throws {
        let mark: [UInt8] = encoding == .utf16LittleEndian ? [0xFF, 0xFE] : [0xFE, 0xFF]
        try (Data(mark) + "ü".data(using: encoding)!).write(to: file)
        #expect(try FileDocumentStore().read(file) == "ü")
    }

    @Test func readsUTF8FileWithMark() throws {
        try (Data([0xEF, 0xBB, 0xBF]) + Data("ü".utf8)).write(to: file)
        #expect(try FileDocumentStore().read(file) == "ü")
    }

    @Test func missingFileThrows() {
        #expect(throws: (any Error).self) { try FileDocumentStore().read(file) }
    }
}

struct MarkdownFileLocatorTests {
    private static let folder = URL(fileURLWithPath: "/vault")

    private static func locator(_ files: String...) -> MarkdownFileLocator {
        MarkdownFileLocator(
            fileExists: { files.contains($0.path) },
            findFiles: { root, name in
                files.filter { $0.hasPrefix(root.path) && URL(fileURLWithPath: $0).lastPathComponent.caseInsensitiveCompare(name) == .orderedSame }
                    .map { URL(fileURLWithPath: $0) }
            })
    }

    @Test func existingPathIsUsedAsIs() {
        let found = Self.locator("/vault/Note.md", "/vault/a/Note.md").locate(URL(fileURLWithPath: "/vault/Note.md"), documentFolder: Self.folder)
        #expect(found?.path == "/vault/Note.md")
    }

    @Test func missingPathFallsBackToClosestFileWithSameName() {
        let found = Self.locator("/vault/b/c/Note.md", "/vault/b/Note.md", "/vault/z/Note.md")
            .locate(URL(fileURLWithPath: "/vault/x/Note.md"), documentFolder: Self.folder)
        #expect(found?.path == "/vault/b/Note.md")
    }

    @Test(arguments: [Self.folder, nil])
    func nothingFoundReturnsNil(_ folder: URL?) {
        #expect(Self.locator("/vault/Other.md").locate(URL(fileURLWithPath: "/vault/Note.md"), documentFolder: folder) == nil)
    }

    @Test func searchesTheDocumentFolderTreeOnDisk() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("md-locator-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let nested = root.appendingPathComponent("a/b")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data().write(to: nested.appendingPathComponent("Note.md"))
        let found = MarkdownFileLocator().locate(root.appendingPathComponent("note.md"), documentFolder: root)
        #expect(found?.standardizedFileURL.path.hasSuffix("/a/b/Note.md") == true)
    }
}

final class FileDocumentWatcherTests {
    private static let eventTimeout: TimeInterval = 10
    private static let quietPeriod: TimeInterval = 0.5

    private let folder = FileManager.default.temporaryDirectory.appendingPathComponent("md-watcher-\(UUID().uuidString)")
    private let watcher = FileDocumentWatcher()
    private let changed = DispatchSemaphore(value: 0)
    private let file: URL

    init() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        file = folder.appendingPathComponent("doc.md")
        try Data("one".utf8).write(to: file)
        watcher.onChange = { [changed] in changed.signal() }
    }

    deinit {
        watcher.watch(nil)
        try? FileManager.default.removeItem(at: folder)
    }

    @Test func signalsWhenTheWatchedFileIsRewritten() throws {
        watcher.watch(file)
        let handle = try FileHandle(forWritingTo: file)
        try handle.write(contentsOf: Data("two".utf8))
        try handle.close()
        #expect(changed.wait(timeout: .now() + Self.eventTimeout) == .success)
    }

    @Test func signalsWhenTheWatchedFileIsReplacedByARename() throws {
        watcher.watch(file)
        try Data("two".utf8).write(to: file, options: .atomic)
        #expect(changed.wait(timeout: .now() + Self.eventTimeout) == .success)
    }

    @Test func keepsSignalingAfterTheFileWasReplaced() throws {
        watcher.watch(file)
        try Data("two".utf8).write(to: file, options: .atomic)
        #expect(changed.wait(timeout: .now() + Self.eventTimeout) == .success)
        while changed.wait(timeout: .now() + Self.quietPeriod) == .success {}
        try Data("three".utf8).write(to: file, options: .atomic)
        #expect(changed.wait(timeout: .now() + Self.eventTimeout) == .success)
    }

    @Test func staysSilentForOtherFilesAndAfterWatchingStops() throws {
        watcher.watch(file)
        try Data("x".utf8).write(to: folder.appendingPathComponent("other.md"))
        #expect(changed.wait(timeout: .now() + Self.quietPeriod) == .timedOut)
        watcher.watch(nil)
        try Data("two".utf8).write(to: file, options: .atomic)
        #expect(changed.wait(timeout: .now() + Self.quietPeriod) == .timedOut)
    }
}

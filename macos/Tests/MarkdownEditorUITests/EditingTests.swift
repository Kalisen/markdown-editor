import AppKit
import Testing
import MarkdownEditorCore
@testable import MarkdownEditorUI

struct ScrollSynchronizerTests {
    private final class Recorder {
        var preview: [ScrollPosition] = []
        var editor: [ScrollPosition] = []
    }

    private let recorder = Recorder()
    private let sync: ScrollSynchronizer

    init() {
        let recorder = recorder
        sync = ScrollSynchronizer(scrollPreview: { recorder.preview.append($0) }, scrollEditor: { recorder.editor.append($0) })
    }

    @Test func editorDrivesByDefault() {
        sync.editorScrolled(to: ScrollPosition(line: 3.5, tail: 0.25))
        #expect(recorder.preview == [ScrollPosition(line: 3.5, tail: 0.25)])
    }

    @Test func previewScrollMovesTheEditorWithoutEchoingBack() {
        sync.previewScrolled(to: ScrollPosition(line: 7.25))
        sync.editorScrolled(to: ScrollPosition(line: 7.25)) // the editor following
        #expect(recorder.editor == [ScrollPosition(line: 7.25)])
        #expect(recorder.preview.isEmpty)
        #expect(sync.driver == .preview)
    }

    @Test func editorInputTakesTheLeadBack() {
        sync.previewScrolled(to: ScrollPosition(line: 7))
        sync.editorReceivedInput()
        sync.editorScrolled(to: ScrollPosition(line: 9))
        #expect(recorder.preview == [ScrollPosition(line: 9)])
    }

    @Test(arguments: [(150.0, 100.0, 200.0, 0.5), (100.0, 100.0, 100.0, 0.0), (250.0, 100.0, 200.0, 1.0)])
    func fractionOfALineSpan(offset: Double, top: Double, bottom: Double, expected: Double) {
        #expect(EditorLineGeometry.fraction(of: offset, from: top, to: bottom) == expected)
    }
}

struct LineIndexTests {
    @Test func linesEndAtLineFeedCarriageReturnOrBoth() {
        let index = LineIndex("a\nbc\r\nd\re" as NSString)
        #expect(index.lineStarts == [0, 2, 6, 8])
        #expect(index.lineCount == 4)
    }

    @Test func emptyTextAndTrailingLineEndingHaveALastEmptyLine() {
        #expect(LineIndex("").lineCount == 1)
        #expect(LineIndex("a\n").lineStarts == [0, 2])
    }

    @Test(arguments: [(0, 0), (1, 0), (2, 1), (5, 1), (6, 2), (100, 2)])
    func findsTheLineOfAnOffset(offset: Int, line: Int) {
        #expect(LineIndex("a\nbc\r\nd" as NSString).line(at: offset) == line)
    }

    @Test func lineRangesIncludeTheLineEnding() {
        let index = LineIndex("a\nbc\r\nd" as NSString)
        #expect(index.range(ofLine: 1, textLength: 7) == NSRange(location: 2, length: 4))
        #expect(index.range(ofLine: 2, textLength: 7) == NSRange(location: 6, length: 1))
    }
}

struct MarkdownSyntaxHighlighterTests {
    private func styles(_ text: String) -> [String: MarkdownSyntaxStyle] {
        Dictionary(MarkdownSyntaxHighlighter.spans(in: text).map { ((text as NSString).substring(with: $0.range), $0.style) }, uniquingKeysWith: { first, _ in first })
    }

    @Test func headingsQuotesAndListMarkersAreHighlightedByLine() {
        let found = styles("# Title\n\n> quote *x*\n\n- item\n12. other\n#notheading\n")
        #expect(found["# Title"] == .heading)
        #expect(found["> quote *x*"] == .quote)
        #expect(found["-"] == .listMarker)
        #expect(found["12."] == .listMarker)
        #expect(found["#notheading"] == nil)
    }

    @Test func inlineCodeStrongEmphasisAndLinksAreHighlighted() {
        let found = styles("Some `code`, **strong**, __strong2__, *em*, _em2_ and [text](url) ![img](a.png).")
        #expect(found["`code`"] == .code)
        #expect(found["**strong**"] == .strong)
        #expect(found["__strong2__"] == .strong)
        #expect(found["*em*"] == .emphasis)
        #expect(found["_em2_"] == .emphasis)
        #expect(found["[text](url)"] == .link)
        #expect(found["![img](a.png)"] == .link)
    }

    @Test func fencedCodeSpansLinesAndHidesMarkdownInside() {
        let text = "a\n```js\n# not a heading\n*x*\n```\n# heading\n~~~\ncode\n"
        let spans = MarkdownSyntaxHighlighter.spans(in: text)
        #expect(spans.map(\.style) == [.code, .code, .code, .code, .heading, .code, .code])
    }

    @Test(arguments: [("```\ncode\n ``` \nafter", 3), ("   ~~~js\ncode\n```js\nstill code", 4), ("    ```\nnot a fence", 0), ("``\nnot a fence", 0)])
    func fencesOpenWithThreeMarkersAndCloseOnAMarkerOnlyLine(text: String, codeLines: Int) {
        #expect(MarkdownSyntaxHighlighter.spans(in: text).filter { $0.style == .code }.count == codeLines)
    }

    @Test func highlightingARangeOfLinesKnowsTheFencesBeforeIt() {
        let text = "```\ncode\nmore *code*\n```\nafter *em*\n" as NSString
        let index = LineIndex(text)
        #expect(MarkdownSyntaxHighlighter.spans(forLines: 2..<3, of: text, lineIndex: index) == [.init(range: NSRange(location: 9, length: 11), style: .code)])
        #expect(MarkdownSyntaxHighlighter.spans(forLines: 4..<5, of: text, lineIndex: index).map(\.style) == [.emphasis])
    }

    @Test func stylesKeepTheEditorFontSizeAndAddTraits() {
        let base = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        let heading = MarkdownSyntaxStyle.heading.attributes(baseFont: base)[.font] as? NSFont
        #expect(heading?.pointSize == 14)
        #expect(heading?.fontDescriptor.symbolicTraits.contains(.bold) == true)
        #expect((MarkdownSyntaxStyle.emphasis.attributes(baseFont: base)[.font] as? NSFont)?.fontDescriptor.symbolicTraits.contains(.italic) == true)
        #expect(MarkdownSyntaxStyle.code.attributes(baseFont: base)[.font] == nil)
    }
}

@MainActor
struct MarkdownTextViewTests {
    @Test func editorDoesNotAlterTypedMarkdown() {
        let textView = MarkdownTextView.make()
        #expect(!textView.isRichText)
        #expect(!textView.isAutomaticQuoteSubstitutionEnabled)
        #expect(!textView.isAutomaticDashSubstitutionEnabled)
        #expect(!textView.isAutomaticTextReplacementEnabled)
        #expect(!textView.isAutomaticSpellingCorrectionEnabled)
        #expect(textView.font?.isFixedPitch == true)
    }

    @Test func newLineKeepsTheIndentationOfTheCurrentLine() {
        let textView = MarkdownTextView.make()
        textView.load("- a\n  - nested")
        textView.setSelectedRange(NSRange(location: 14, length: 0))
        textView.insertNewline(nil)
        textView.insertText("- more", replacementRange: textView.selectedRange())
        #expect(textView.string == "- a\n  - nested\n  - more")
        textView.setSelectedRange(NSRange(location: 3, length: 0))
        textView.insertNewline(nil)
        #expect(textView.string == "- a\n\n  - nested\n  - more")
    }

    @Test func loadingTextIndexesItsLinesAndClearsUndo() {
        let textView = MarkdownTextView.make()
        textView.insertText("typed", replacementRange: NSRange(location: 0, length: 0))
        textView.load("a\nb\nc")
        #expect(textView.string == "a\nb\nc")
        #expect(textView.lineIndex.lineCount == 3)
        #expect(textView.undoManager?.canUndo != true)
    }
}

struct SharedAssetsTests {
    @Test func locatesTheFolderNamedByTheEnvironment() throws {
        let shared = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("shared")
        let assets = try #require(SharedAssets.locate(bundle: Bundle(for: MarkdownTextView.self), environment: [SharedAssets.environmentVariable: shared.path]))
        #expect(assets.previewFolder.lastPathComponent == "preview")
        #expect(assets.pluginsFolder.lastPathComponent == "plugins")
    }

    @Test func missingAssetsAreReported() {
        #expect(SharedAssets.locate(bundle: Bundle(for: MarkdownTextView.self), environment: [SharedAssets.environmentVariable: "/nonexistent"]) == nil)
    }
}

@MainActor
struct AppDelegateTests {
    @Test(arguments: [
        (["MarkdownEditor", "/docs/a.md"], "/docs/a.md"),
        (["MarkdownEditor", "-NSDocumentRevisionsDebugMode", "YES", "/docs/a.md", "/docs/b.md"], "/docs/a.md"),
        (["MarkdownEditor"], nil),
        (["MarkdownEditor", "-ApplePersistenceIgnoreState", "YES"], nil),
    ] as [([String], String?)])
    func firstPlainCommandLineArgumentIsTheFileToOpen(arguments: [String], path: String?) {
        #expect(AppDelegate.fileArgument(arguments)?.path == path)
    }
}

@MainActor
struct EditorLineGeometryTests {
    /// A long document in a scroll view, as in the editor window.
    private func makeEditor(lines: Int) -> (MarkdownTextView, NSScrollView) {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let textView = MarkdownTextView.make()
        textView.frame = NSRect(origin: .zero, size: scrollView.contentSize)
        scrollView.documentView = textView
        textView.load((0..<lines).map { "Line \($0)" }.joined(separator: "\n"))
        return (textView, scrollView)
    }

    @Test func positionIsTheSourceLineAtTheTopAndRoundTrips() {
        let (textView, scrollView) = makeEditor(lines: 2000)
        let geometry = EditorLineGeometry(textView: textView, scrollView: scrollView, lineIndex: textView.lineIndex)
        let offset = geometry.offset(for: ScrollPosition(line: 1000.5))
        textView.scroll(NSPoint(x: 0, y: offset))
        let position = EditorLineGeometry(textView: textView, scrollView: scrollView, lineIndex: textView.lineIndex).position
        #expect(abs(position.line - 1000.5) < 0.05)
        #expect(position.tail == 0)
    }

    @Test func aLongDocumentBeingLaidOutIsNotMistakenForItsEnd() {
        let (textView, scrollView) = makeEditor(lines: 20000)
        // The view is only as tall as the part of the text laid out so far, and is scrolled to the end of that part.
        let laidOutHeight: CGFloat = 3000
        textView.setFrameSize(NSSize(width: textView.frame.width, height: laidOutHeight))
        textView.scroll(NSPoint(x: 0, y: laidOutHeight - scrollView.contentSize.height))
        let position = EditorLineGeometry(textView: textView, scrollView: scrollView, lineIndex: textView.lineIndex).position
        #expect(position.tail == 0)
        #expect(position.line > 50 && position.line < 2000)
    }

    @Test func theLastViewportBlendsTowardTheEnd() {
        let (textView, scrollView) = makeEditor(lines: 500)
        let geometry = EditorLineGeometry(textView: textView, scrollView: scrollView, lineIndex: textView.lineIndex)
        let end = geometry.offset(for: ScrollPosition(line: 0, tail: 1))
        textView.scroll(NSPoint(x: 0, y: end))
        #expect(EditorLineGeometry(textView: textView, scrollView: scrollView, lineIndex: textView.lineIndex).position.tail == 1)
        #expect(geometry.offset(for: ScrollPosition(line: 0)) == 0)
    }
}

import AppKit
import Foundation
import Testing
import TestSupport
import WebKit
import MarkdownEditorCore
import MarkdownEditorPlugins
@testable import MarkdownEditorUI

/// The real preview page in a WKWebView, with every bundled plugin and the shared assets.
@MainActor
final class PreviewHostTests {
    private static let timeout: TimeInterval = 30

    private let catalog = PluginCatalog(bundled: BundledPlugins.all, pluginsFolder: SharedFiles.plugins)
    private let renderer = MarkdownRenderer(plugins: BundledPlugins.all)
    private let documentFolder = FileManager.default.temporaryDirectory.appendingPathComponent("md-preview-\(UUID().uuidString)")
    private let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
    private var host: PreviewHost!

    init() throws {
        try FileManager.default.createDirectory(at: documentFolder, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: documentFolder)
    }

    /// Shows `markdown` in a ready preview page.
    private func show(_ markdown: String, theme: PreviewTheme = .light) async throws {
        host = PreviewHost(plugins: catalog.plugins, previewFolder: SharedFiles.preview, theme: theme)
        host.setDocumentFolder(documentFolder)
        host.webView.frame = window.contentView!.bounds
        window.contentView!.addSubview(host.webView)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            host.onReady = { continuation.resume() }
            host.load()
        }
        host.onReady = nil
        host.render(renderer.renderDocument(markdown, annotateSourceLines: true).html)
    }

    private func evaluate(_ expression: String) async throws -> Any? {
        try await host.webView.callAsyncJavaScript("return (\(expression));", arguments: [:], in: nil, contentWorld: .page)
    }

    /// Polls until the JavaScript condition holds.
    private func waitUntil(_ condition: String, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        let deadline = Date().addingTimeInterval(Self.timeout)
        while Date() < deadline {
            if try await evaluate(condition) as? Bool == true { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        Issue.record("Timed out waiting for: \(condition)", sourceLocation: sourceLocation)
    }

    @Test func pluginsDrawDiagramsMathAndHighlightingInThePage() async throws {
        try await show("# Title\n\n```mermaid\ngraph TD\nA-->B\n```\n\n$x^2$\n\n$$\n\\sum_i x_i\n$$\n\n```swift\nlet a = 1\n```\n\n```dot\ndigraph { a -> b }\n```\n")
        try await waitUntil("!!document.querySelector('.mermaid-diagram svg')")
        try await waitUntil("!!document.querySelector('span.math .katex') && !!document.querySelector('div.math .katex-display')")
        try await waitUntil("!!document.querySelector('pre > code.language-swift.hljs .hljs-keyword')")
        try await waitUntil("!!document.querySelector('pre.graphviz-diagram svg')")
        try await waitUntil("!!document.querySelector('h1#title > a.heading-anchor svg')")
        #expect(try await evaluate("window.mdeditor.theme") as? String == "light")
        #expect(try await evaluate("!!document.querySelector('link[href$=\"github.min.css\"]')") as? Bool == true)
    }

    @Test func pluginFontsAndStylesLoadFromThePluginOrigins() async throws {
        try await show("$x^2$\n\n| a |\n| - |\n| 1 |\n")
        try await waitUntil("!!document.querySelector('span.math .katex')")
        #expect(try await host.webView.callAsyncJavaScript(
            "return (await document.fonts.load('16px KaTeX_Main')).length", arguments: [:], in: nil, contentWorld: .page) as? Int ?? 0 > 0)
        #expect(try await evaluate("getComputedStyle(document.querySelector('table')).display") as? String == "block")
    }

    @Test func darkThemeIsAppliedToThePageAndItsPlugins() async throws {
        try await show("```swift\nlet a = 1\n```\n", theme: .dark)
        try await waitUntil("!!document.querySelector('link[href$=\"github-dark.min.css\"]')")
        #expect(try await evaluate("document.documentElement.dataset.theme") as? String == "dark")
        #expect(try await evaluate("getComputedStyle(document.body).backgroundColor") as? String == "rgb(13, 17, 23)")
    }

    @Test func scriptsInTheDocumentDoNotRun() async throws {
        try Data("window.__ran = 'file';".utf8).write(to: documentFolder.appendingPathComponent("evil.js"))
        try await show("<img id=\"probe\" src=\"missing.png\" onerror=\"window.__ran = 'handler'\">\n\n<script>window.__ran = 'inline'</script>\n\n"
            + "<script src=\"mdeditor://doc.mdeditor.local/evil.js\"></script>\n\n<a id=\"js\" href=\"javascript:window.__ran='link'\">x</a>\n\ntext\n")
        try await waitUntil("document.getElementById('probe').complete")
        _ = try await evaluate("document.getElementById('js').click()")
        // A script element added by the page itself is subject to the same policy.
        _ = try await evaluate("(() => { const s = document.createElement('script'); s.src = 'mdeditor://doc.mdeditor.local/evil.js'; document.body.appendChild(s); return true; })()")
        try await Task.sleep(nanoseconds: 500_000_000)
        #expect(try await evaluate("window.__ran === undefined") as? Bool == true)
        #expect(try await evaluate("document.querySelector('main').textContent.includes('text')") as? Bool == true)
    }

    @Test func imagesOfTheDocumentFolderAreShown() async throws {
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAIAAAADCAYAAAC56t6BAAAAEklEQVR4nGP8z8Dwn4EIwDiqEAC1LQP/7gyYPwAAAABJRU5ErkJggg==")!
        try FileManager.default.createDirectory(at: documentFolder.appendingPathComponent("img"), withIntermediateDirectories: true)
        try png.write(to: documentFolder.appendingPathComponent("img/a b.png"))
        try await show("![alt](<img/a b.png>)\n\n![missing](nope.png)\n")
        try await waitUntil("document.images.length === 2 && Array.from(document.images).every((i) => i.complete)")
        #expect(try await evaluate("document.images[0].naturalWidth") as? Int == 2)
        #expect(try await evaluate("document.images[1].naturalWidth") as? Int == 0)
    }

    @Test func clickingAMarkdownLinkAsksToOpenItAndWikilinksAreSearchedInSubfolders() async throws {
        try FileManager.default.createDirectory(at: documentFolder.appendingPathComponent("notes"), withIntermediateDirectories: true)
        try Data().write(to: documentFolder.appendingPathComponent("other.md"))
        try Data().write(to: documentFolder.appendingPathComponent("notes/Deep.md"))
        try await show("[other](other.md) [[Deep]] [missing](gone.md)\n")
        var requested: [String] = []
        host.onOpenDocumentRequested = { requested.append($0.standardizedFileURL.path) }
        for index in 0..<3 { _ = try await evaluate("document.querySelectorAll('a')[\(index)].click()") }
        let deadline = Date().addingTimeInterval(Self.timeout)
        while requested.count < 3, Date() < deadline { try await Task.sleep(nanoseconds: 50_000_000) }
        let folder = documentFolder.standardizedFileURL.path
        #expect(requested == ["\(folder)/other.md", "\(folder)/notes/Deep.md", "\(folder)/gone.md"])
        #expect(try await evaluate("location.href") as? String == PreviewResources.shellURL.absoluteString)
    }

    @Test func previewFollowsTheEditorScrollPositionAndKeepsUnchangedBlocks() async throws {
        let markdown = (0..<200).map { "Paragraph \($0)\n" }.joined(separator: "\n")
        try await show(markdown + "\n```mermaid\ngraph TD\nA-->B\n```\n")
        try await waitUntil("document.querySelectorAll('[data-line]').length > 200 && !!document.querySelector('.mermaid-diagram svg')")
        host.scroll(to: ScrollPosition(line: 200))
        try await waitUntil("window.scrollY > 1000")
        let top = try #require(try await evaluate("document.querySelector('[data-line=\"200\"]').getBoundingClientRect().top") as? Double)
        #expect(abs(top) < 2)

        // An edit elsewhere keeps the drawn diagram (the page only replaces the blocks that changed).
        _ = try await evaluate("document.querySelector('.mermaid-diagram').dataset.kept = '1'")
        host.render(renderer.renderDocument("Inserted\n\n" + markdown + "\n```mermaid\ngraph TD\nA-->B\n```\n", annotateSourceLines: true).html)
        try await waitUntil("document.querySelector('main').firstElementChild.textContent === 'Inserted'")
        #expect(try await evaluate("document.querySelector('.mermaid-diagram').dataset.kept") as? String == "1")
        #expect(try await evaluate("document.querySelector('.mermaid-diagram').dataset.line") as? String == "402")
    }

    @Test func snapshotExportsAStandaloneHtmlPage() async throws {
        try await show("# Title\n\n```swift\nlet a = 1\n```\n\n![alt](img/a.png)\n")
        try await waitUntil("!!document.querySelector('pre > code.hljs')")
        let snapshot = try #require(await host.snapshot())
        #expect(snapshot.contentHTML.contains("<h1 id=\"title\""))
        #expect(snapshot.stylesheetURLs.contains("mdeditor://app.mdeditor.local/preview.css"))
        #expect(snapshot.stylesheetURLs.contains { $0.hasSuffix("highlightjs-11.12.0/github.min.css") })

        let html = HTMLExportBuilder.build(title: "Doc", snapshot: snapshot, theme: .light) { url in
            host.stylesheetFile(url).flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        }
        #expect(html.contains(".markdown-body"))
        #expect(html.contains(".hljs-keyword"))
        #expect(html.contains("<img src=\"img/a.png\""))
        #expect(!html.contains("<script"))
        #expect(!html.contains("=\"\(PreviewOrigins.scheme)://"))
    }

    @Test func exportsThePreviewAsAPdfFile() async throws {
        try await show("# Title\n\ntext\n")
        try await waitUntil("!!document.querySelector('h1#title')")
        let file = documentFolder.appendingPathComponent("out.pdf")
        #expect(await host.exportPDF(to: file) == .exported)
        #expect(try Data(contentsOf: file).prefix(5) == Data("%PDF-".utf8))
    }
}

import CommonMark
import Foundation
import Testing
import TestSupport
@testable import MarkdownEditorCore

struct MarkdownRendererTests {
    @Test func corePipelineDoesNotEnableNonCommonMarkSyntax() {
        #expect(MarkdownRenderer().render("~~x~~") == "<p>~~x~~</p>\n")
    }

    @Test func pluginExtensionsAreApplied() {
        let plugin = FakePlugin(id: "strike", configure: { $0.addEmphasisDelimiter(strikethroughDelimiter) })
        #expect(MarkdownRenderer(plugins: [plugin]).render("~~x~~") == "<p><del>x</del></p>\n")
    }

    @Test func renderDocumentReportsPluginsWhoseProbeMatches() {
        let usesStrike = ProbingPlugin(id: "strike") { $0.hasDescendant(ofType: Emphasis.self) { $0.delimiter == UInt8(ascii: "~") } }
        let never = ProbingPlugin(id: "never") { _ in false }
        let renderer = MarkdownRenderer(plugins: [usesStrike, never, FakePlugin(id: "no-probe")])
        let used = renderer.renderDocument("~~x~~")
        #expect(used.html == "<p><del>x</del></p>\n")
        #expect(used.usedPlugins.map(\.id) == ["strike"])
        #expect(renderer.renderDocument("plain").usedPlugins.isEmpty)
    }

    @Test func failingPluginIsExcludedAndReported() {
        let bad = FakePlugin(id: "bad", configure: { _ in throw TestError(message: "boom") })
        let renderer = MarkdownRenderer(plugins: [bad, FakePlugin(id: "good")])
        #expect(renderer.activePlugins.map(\.id) == ["good"])
        #expect(renderer.failures == [PluginLoadFailure(source: "bad", reason: "boom")])
        #expect(renderer.render("ok") == "<p>ok</p>\n")
    }
}

struct SourceLineAnnotatorTests {
    private func annotated(_ markdown: String) -> String {
        MarkdownRenderer().renderDocument(markdown, annotateSourceLines: true).html
    }

    @Test func blocksCarryTheirFirstAndLastSourceLines() {
        let html = annotated("# Title\n\nfirst line\nsecond line\n")
        #expect(html.contains("<h1 data-line=\"0\" data-line-end=\"0\">"))
        #expect(html.contains("<p data-line=\"2\" data-line-end=\"3\">"))
    }

    @Test func nestedBlocksAreAnnotated() {
        let html = annotated("- a\n- b\n")
        #expect(html.contains("<ul data-line=\"0\" data-line-end=\"1\">"))
        #expect(html.contains("<li data-line=\"1\" data-line-end=\"1\">"))
    }

    @Test func containersEndAtTheirLastContentLineNotAtTrailingBlankLines() {
        let html = annotated("> a\n> b\n\n\n1. x\n\n   y\n\n\nend\n")
        #expect(html.contains("<blockquote data-line=\"0\" data-line-end=\"1\">"))
        #expect(html.contains("<ol data-line=\"4\" data-line-end=\"6\">"))
        #expect(html.contains("<p data-line=\"9\" data-line-end=\"9\">"))
    }

    @Test func codeBlocksAndSetextHeadingsCoverAllTheirLines() {
        let html = annotated("Title\n=====\n\n    a\n\n    b\n\n\ntext\n")
        #expect(html.contains("<h1 data-line=\"0\" data-line-end=\"1\">"))
        #expect(html.contains("<pre><code data-line=\"3\" data-line-end=\"5\">"))
    }

    @Test func carriageReturnLineBreaksAreCountedOnce() {
        let html = annotated("a\r\nb\r\n\r\n```\r\ncode\r\n```\r\n")
        #expect(html.contains("data-line=\"3\" data-line-end=\"5\""))
    }

    @Test func plainRenderingIsNotAnnotated() {
        #expect(MarkdownRenderer().render("a") == "<p>a</p>\n")
    }
}

struct PreviewPageBuilderTests {
    private let plugin = FakePlugin(id: "demo", previewAssets: [.stylesheet("a.css"), .script("/js/b.js")])
    private var html: String { PreviewPageBuilder.build(theme: .dark, plugins: [plugin]).html }
    private var policy: String { PreviewPageBuilder.contentSecurityPolicy(pluginIDs: ["demo", "other"]) }

    @Test func pageIncludesThemeHostScriptAndPluginAssetsServedFromPluginOrigin() throws {
        #expect(html.contains("<html data-theme=\"dark\">"))
        #expect(html.contains("<link rel=\"stylesheet\" href=\"mdeditor://demo.plugin.mdeditor.local/a.css\">"))
        #expect(html.contains("<script src=\"mdeditor://demo.plugin.mdeditor.local/js/b.js\"></script>"))
        let hostScript = try #require(html.range(of: "src=\"preview.js\""))
        let pluginScript = try #require(html.range(of: "js/b.js"))
        #expect(hostScript.lowerBound < pluginScript.lowerBound, "host API must load before plugin scripts")
    }

    @Test func sharedPreviewAssetsExposeTheHostApiAndBaseStyles() throws {
        #expect(try String(contentsOf: SharedFiles.preview.appendingPathComponent(PreviewPageBuilder.scriptFileName), encoding: .utf8).contains("window.mdeditor = {"))
        #expect(try String(contentsOf: SharedFiles.preview.appendingPathComponent(PreviewPageBuilder.styleFileName), encoding: .utf8).contains(".markdown-body"))
    }

    @Test func pageHasNoInlineScriptAndDeclaresPolicy() {
        #expect(!html.contains("<script>"))
        #expect(html.contains("<meta http-equiv=\"Content-Security-Policy\" content=\"\(PreviewPageBuilder.contentSecurityPolicy(pluginIDs: ["demo"]))\">"))
    }

    @Test(arguments: [
        "default-src 'none'",
        "script-src mdeditor://app.mdeditor.local mdeditor://demo.plugin.mdeditor.local mdeditor://other.plugin.mdeditor.local 'wasm-unsafe-eval';",
        "img-src mdeditor://doc.mdeditor.local https: data:;",
        "connect-src 'none'", "frame-src 'none'", "object-src 'none'", "base-uri 'none'", "form-action 'none'",
    ])
    func policyRestricts(_ directive: String) {
        #expect(policy.contains(directive))
    }

    @Test func policyNeverAllowsInlineOrEvalScriptNorScriptFromTheDocumentFolder() throws {
        let script = try #require(policy.components(separatedBy: "; ").first { $0.hasPrefix("script-src") })
        #expect(!script.contains("'unsafe-eval'"))
        #expect(!script.contains("'unsafe-inline'"))
        #expect(!script.contains(PreviewOrigins.documentHost))
        #expect(!script.contains("*"))
        #expect(script.contains("'wasm-unsafe-eval'"))
    }

    @Test func policyWithoutPluginsHasNoEmptySource() {
        #expect(PreviewPageBuilder.contentSecurityPolicy(pluginIDs: []).contains("font-src data:;"))
    }
}

struct PreviewLinkPolicyTests {
    private static let folder = URL(fileURLWithPath: "/docs")

    @Test(arguments: ["https://example.org/a?b=1", "http://example.org", "mailto:me@example.org", "HTTPS://EXAMPLE.org/x"])
    func externalLinksOpenExternally(_ href: String) {
        #expect(PreviewLinkPolicy.classify(href, documentFolder: Self.folder) == .openExternal(URL(string: href)!))
    }

    @Test(arguments: [
        ("other.md", "/docs/other.md"),
        ("sub/My%20Notes.markdown", "/docs/sub/My Notes.markdown"),
        ("mdeditor://doc.mdeditor.local/sub/x.md", "/docs/sub/x.md"),
        ("../other/x.md#part", "/other/x.md"),
        ("x.MD?query", "/docs/x.MD"),
    ])
    func markdownLinksRelativeToTheDocumentFolderOpenInEditor(href: String, path: String) {
        #expect(PreviewLinkPolicy.classify(href, documentFolder: Self.folder) == .openDocument(URL(fileURLWithPath: path)))
    }

    @Test(arguments: [
        "#section", "", "   ", "image.png", "mdeditor://app.mdeditor.local/index.html", "mdeditor://mermaid.plugin.mdeditor.local/x.js",
        "file:///Applications/Calculator.app", "javascript:alert(1)", "C:\\Windows\\notepad.exe", "/", "%zz.md",
    ])
    func otherLinksAreIgnored(_ href: String) {
        #expect(PreviewLinkPolicy.classify(href, documentFolder: Self.folder) == .ignore)
    }

    @Test func missingLinkIsIgnored() {
        #expect(PreviewLinkPolicy.classify(nil, documentFolder: Self.folder) == .ignore)
    }

    @Test func relativeLinksAreIgnoredForUntitledDocuments() {
        #expect(PreviewLinkPolicy.classify("other.md", documentFolder: nil) == .ignore)
    }
}

struct PreviewMessagesTests {
    @Test func parsesReadyAndOpenLinkMessages() {
        #expect(PreviewMessages.parse(#"{"type":"ready"}"#) == .ready)
        #expect(PreviewMessages.parse(#"{"type":"open-link","href":"a.md"}"#) == .openLink(href: "a.md"))
    }

    @Test(arguments: [nil, "", "not json", "\"ready\"", #"{"type":1}"#, #"{"type":"other"}"#, #"{"type":"open-link"}"#, #"{"type":"open-link","href":{}}"#, "[]"])
    func malformedOrUnknownMessagesAreIgnored(_ json: String?) {
        #expect(PreviewMessages.parse(json) == nil)
    }

    @Test(arguments: [(12.5, 0.5, 12.5, 0.5), (-1.0, 2.0, 0.0, 1.0)])
    func scrollToLineIsClamped(line: Double, tail: Double, expectedLine: Double, expectedTail: Double) throws {
        let json = PreviewMessages.scrollToLine(ScrollPosition(line: line, tail: tail))
        let message = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        #expect(message["type"] as? String == PreviewMessages.scrollToLineType)
        #expect(message["line"] as? Double == expectedLine)
        #expect(message["tail"] as? Double == expectedTail)
    }

    @Test(arguments: [(#"{"type":"scrolled","line":4.25,"tail":0.5}"#, 0.5), (#"{"type":"scrolled","line":4.25}"#, 0.0), (#"{"type":"scrolled","line":4.25,"tail":3}"#, 1.0)])
    func parsesScrolledMessage(json: String, tail: Double) {
        #expect(PreviewMessages.parse(json) == .scrolled(ScrollPosition(line: 4.25, tail: tail)))
    }

    @Test(arguments: [#"{"type":"scrolled"}"#, #"{"type":"scrolled","line":"4"}"#, #"{"type":"scrolled","line":-1}"#, #"{"type":"scrolled","line":true}"#])
    func malformedScrolledMessagesAreIgnored(_ json: String) {
        #expect(PreviewMessages.parse(json) == nil)
    }
}

struct ScrollTailTests {
    // Scroll range [0, 1000] with a 300 px viewport: the tail is [700, 1000].
    @Test(arguments: [(500.0, 0.0), (700.0, 0.0), (850.0, 0.5), (1000.0, 1.0)])
    func progressThroughTheLastViewport(offset: Double, expected: Double) {
        #expect(ScrollTail.progress(offset: offset, maxOffset: 1000, viewport: 300) == expected)
    }

    @Test func contentShorterThanTwoViewportsBlendsOverTheWholeRange() {
        #expect(ScrollTail.progress(offset: 100, maxOffset: 200, viewport: 300) == 0.5)
    }

    @Test func nothingToScrollHasNoTail() {
        #expect(ScrollTail.progress(offset: 0, maxOffset: 0, viewport: 300) == 0)
    }

    @Test(arguments: [(0.0, 400.0), (0.5, 1200.0), (1.0, 2000.0)])
    func blendMovesTheFollowerTowardItsEnd(tail: Double, expected: Double) {
        #expect(ScrollTail.blend(lineOffset: 400, maxOffset: 2000, tail: tail) == expected)
    }
}

struct BackgroundRendererTests {
    @Test func doesNotBlockTheCallerWhileRendering() async {
        let gate = DispatchSemaphore(value: 0)
        let renderer = BackgroundRenderer<String> { markdown in
            gate.wait()
            return markdown.uppercased()
        }
        async let pending = renderer.render("a") // would deadlock if rendering ran on the caller
        gate.signal()
        #expect(await pending == "A")
    }

    @Test func supersededRenderYieldsNil() async {
        let gate = DispatchSemaphore(value: 0)
        let started = DispatchSemaphore(value: 0)
        let renderer = BackgroundRenderer<String> { markdown in
            if markdown == "old" {
                started.signal()
                gate.wait()
            }
            return markdown
        }
        async let older = renderer.render("old")
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                started.wait()
                continuation.resume()
            }
        }
        #expect(await renderer.render("new") == "new")
        gate.signal()
        #expect(await older == nil)
    }

    @Test func rendersDeeplyNestedDocumentsWithoutExhaustingTheStack() async {
        let renderer = BackgroundRenderer<String> { MarkdownRenderer().render($0) }
        let nested = String(repeating: "> ", count: 5000) + "deep\n" + String(repeating: "*a ", count: 20000) + String(repeating: "a* ", count: 20000)
        #expect(await renderer.render(nested)?.contains("deep") == true)
    }
}

struct ExportTests {
    @Test func buildsStandalonePageWithInlinedResolvableStylesAndNoScripts() {
        let snapshot = PreviewSnapshot(contentHTML: "<h1>Hi</h1><svg></svg>", stylesheetURLs: ["mdeditor://a/x.css", "mdeditor://a/missing.css", "mdeditor://a/x.css"])
        let html = HTMLExportBuilder.build(title: "My <Doc>", snapshot: snapshot, theme: .light) { $0.hasSuffix("x.css") ? "body{color:red}</style>" : nil }
        #expect(html.contains("<title>My &lt;Doc&gt;</title>"))
        #expect(html.contains("<html data-theme=\"light\">"))
        #expect(html.contains("<main id=\"content\" class=\"markdown-body\">\n<h1>Hi</h1><svg></svg>\n</main>"))
        #expect(html.components(separatedBy: "body{color:red}").count == 2)
        #expect(html.contains("<\\/style>"))
        #expect(!html.contains("missing.css */"))
        #expect(!html.contains("<script"))
    }

    @Test(arguments: [(ExportFormat.html, "html"), (.pdf, "pdf")])
    func exportFormatsHaveAFileExtension(format: ExportFormat, fileExtension: String) {
        #expect(format.fileExtension == fileExtension)
    }
}

struct PreviewResourcesTests {
    private static let page = PreviewPage(html: "<html></html>")
    private static let math = LoadedPlugin(plugin: FakePlugin(id: "math"), folder: URL(fileURLWithPath: "/plugins/math"))

    private func resources(documentFolder: URL? = URL(fileURLWithPath: "/docs")) -> PreviewResources {
        PreviewResources(page: Self.page, previewFolder: URL(fileURLWithPath: "/app/preview"), plugins: [Self.math], documentFolder: documentFolder)
    }

    @Test func servesTheGeneratedShellPage() {
        #expect(resources().resolve(PreviewResources.shellURL) == .content(Data("<html></html>".utf8), mimeType: "text/html"))
    }

    @Test(arguments: [
        ("mdeditor://app.mdeditor.local/preview.css", "/app/preview/preview.css"),
        ("mdeditor://math.plugin.mdeditor.local/assets/vendor/katex.min.css", "/plugins/math/assets/vendor/katex.min.css"),
        ("mdeditor://math.plugin.mdeditor.local/a%20b.css", "/plugins/math/a b.css"),
        ("mdeditor://doc.mdeditor.local/img/a.png", "/docs/img/a.png"),
        ("MDEDITOR://DOC.mdeditor.local/a.png", "/docs/a.png"),
    ])
    func resolvesPreviewUrlsToFiles(url: String, path: String) {
        #expect(resources().resolve(URL(string: url)!) == .file(URL(fileURLWithPath: path)))
    }

    @Test(arguments: [
        "https://example.org/x.css", "mdeditor://unknown.plugin.mdeditor.local/x.css", "mdeditor://math.plugin.mdeditor.local/../../secret.css",
        "mdeditor://math.plugin.mdeditor.local/..%2F..%2Fsecret.css", "mdeditor://doc.mdeditor.local/%2E%2E/secret.png",
        "mdeditor://doc.mdeditor.local/", "mdeditor://other.local/x.css", "file:///etc/hosts",
    ])
    func otherUrlsAreNotServed(_ url: String) {
        #expect(resources().resolve(URL(string: url)!) == nil)
    }

    @Test func documentFilesAreNotServedForUntitledDocuments() {
        #expect(resources(documentFolder: nil).resolve(URL(string: "mdeditor://doc.mdeditor.local/a.png")!) == nil)
    }

    @Test func stylesheetFilesExcludeTheDocumentFolder() {
        #expect(resources().stylesheetFile("mdeditor://app.mdeditor.local/preview.css")?.path == "/app/preview/preview.css")
        #expect(resources().stylesheetFile("mdeditor://doc.mdeditor.local/evil.css") == nil)
        #expect(resources().stylesheetFile("not a url") == nil)
    }

    @Test(arguments: [("a.css", "text/css"), ("a.js", "text/javascript"), ("a.woff2", "font/woff2"), ("a.png", "image/png"), ("a.svg", "image/svg+xml"), ("a.unknownext", "application/octet-stream")])
    func mimeTypesFollowTheFileExtension(name: String, mimeType: String) {
        #expect(PreviewResources.mimeType(of: URL(fileURLWithPath: "/x/\(name)")) == mimeType)
    }
}

import CommonMark
import Foundation
import Testing
import TestSupport
import MarkdownEditorCore
@testable import MarkdownEditorPlugins

struct ImagesPluginTests {
    private func render(_ markdown: String) -> String { MarkdownEditorPluginsTests.render(markdown, with: ImagesPlugin()) }

    @Test(arguments: [
        ("img/a.png", "mdeditor://doc.mdeditor.local/img/a.png"),
        ("./a.png", "mdeditor://doc.mdeditor.local/a.png"),
        ("img\\a.png", "mdeditor://doc.mdeditor.local/img/a.png"),
        ("../up/a.png", "mdeditor://doc.mdeditor.local/../up/a.png"),
        ("https://x.org/a.png", "https://x.org/a.png"),
        ("data:image/png;base64,AA", "data:image/png;base64,AA"),
        ("/root.png", "/root.png"),
        ("C:\\pics\\a.png", "C:\\pics\\a.png"),
        ("#anchor", "#anchor"),
        ("", ""),
    ])
    func resolvesRelativeUrlsAgainstDocumentOrigin(url: String, expected: String) {
        #expect(ImageURLResolver.resolve(url) == expected)
    }

    @Test func rendersRelativeImageLazilyFromDocumentOrigin() {
        #expect(render("![x](a.png \"t\")") == "<p><img src=\"mdeditor://doc.mdeditor.local/a.png\" loading=\"lazy\" alt=\"x\" title=\"t\" /></p>\n")
        #expect(render("![x](<my pic.png>)") == "<p><img src=\"mdeditor://doc.mdeditor.local/my%20pic.png\" loading=\"lazy\" alt=\"x\" /></p>\n")
    }

    @Test(arguments: [("=200x100", "width=\"200\" height=\"100\""), ("=200x", "width=\"200\""), ("=x50", "height=\"50\"")])
    func sizeHintTitleBecomesDimensions(hint: String, attributes: String) {
        #expect(render("![x](a.png \"\(hint)\")") == "<p><img src=\"mdeditor://doc.mdeditor.local/a.png\" \(attributes) loading=\"lazy\" alt=\"x\" /></p>\n")
    }

    @Test(arguments: [nil, "x", "=x", "=axb", "=99999999999x10"])
    func nonHintTitlesAreNotSizeHints(_ title: String?) {
        #expect(ImageSizeHint(title: title) == nil)
    }

    @Test func linksAreNotRewritten() {
        #expect(render("[x](a.md)") == "<p><a href=\"a.md\">x</a></p>\n")
    }

    @Test func declaresStylesheetThatExists() {
        #expect(ImagesPlugin().previewAssets == [.stylesheet(ImagesPlugin.stylesheetPath)])
        #expect(assetExists(ImagesPlugin(), ImagesPlugin.stylesheetPath))
    }
}

struct MermaidPluginTests {
    private func render(_ markdown: String) -> String { MarkdownEditorPluginsTests.render(markdown, with: MermaidPlugin()) }

    @Test func mermaidBlockRendersEscapedSourceInDiagramContainer() {
        #expect(render("```mermaid\ngraph TD\nA-->B<br>\n```") == "<div class=\"mermaid-diagram\"><pre class=\"mermaid-source\">graph TD\nA--&gt;B&lt;br&gt;\n</pre></div>\n")
    }

    @Test(arguments: [
        ("```csharp\nx\n```", "<pre><code class=\"language-csharp\">x\n</code></pre>\n"),
        ("```Mermaid\nx\n```", "<pre><code class=\"language-Mermaid\">x\n</code></pre>\n"),
        ("```\nx\n```", "<pre><code>x\n</code></pre>\n"),
        ("    mermaid", "<pre><code>mermaid\n</code></pre>\n"),
    ])
    func otherCodeBlocksRenderAsCommonMark(markdown: String, html: String) {
        #expect(render(markdown) == html)
    }

    @Test func infoStringAttributesAfterLanguageStillMatch() {
        #expect(render("```mermaid {theme=x}\nx\n```").hasPrefix("<div class=\"mermaid-diagram\">"))
    }

    @Test func diagramCarriesItsSourceLines() {
        let html = MarkdownRenderer(plugins: [MermaidPlugin()]).renderDocument("a\n\n```mermaid\ngraph TD\n```\n", annotateSourceLines: true).html
        #expect(html.contains("<div class=\"mermaid-diagram\" data-line=\"2\" data-line-end=\"4\">"))
    }

    @Test func declaredAssetsExistWithMermaidBeforeBootstrap() throws {
        let paths = MermaidPlugin().previewAssets.map(\.relativePath)
        for path in paths { #expect(assetExists(MermaidPlugin(), path)) }
        #expect(try #require(paths.firstIndex(of: MermaidPlugin.mermaidScriptPath)) < #require(paths.firstIndex(of: MermaidPlugin.bootstrapScriptPath)))
    }

    @Test func bundledMermaidIsTheTargetedVersion() throws {
        let bundle = try readAsset(MermaidPlugin(), MermaidPlugin.mermaidScriptPath)
        #expect(bundle.contains("\"\(MermaidPlugin.mermaidVersion)\""))
        #expect(bundle.hasSuffix("globalThis[\"mermaid\"] = globalThis.__esbuild_esm_mermaid_nm[\"mermaid\"].default;\n"))
    }
}

struct GraphvizPluginTests {
    @Test(arguments: GraphvizPlugin.languages)
    func dotBlocksKeepTheirLanguageClassForThePreviewScript(_ language: String) throws {
        #expect(render("```\(language)\ndigraph { a -> b }\n```", with: GraphvizPlugin()) == "<pre><code class=\"language-\(language)\">digraph { a -&gt; b }\n</code></pre>\n")
        #expect(try readAsset(GraphvizPlugin(), GraphvizPlugin.bootstrapScriptPath).contains("code.language-\(language)"))
    }

    @Test func declaredAssetsExistWithVizBeforeBootstrap() throws {
        let paths = GraphvizPlugin().previewAssets.map(\.relativePath)
        for path in paths { #expect(assetExists(GraphvizPlugin(), path)) }
        #expect(try #require(paths.firstIndex(of: GraphvizPlugin.vizScriptPath)) < #require(paths.firstIndex(of: GraphvizPlugin.bootstrapScriptPath)))
    }

    @Test func bundledVizIsTheTargetedVersionWithLicenseNotice() throws {
        #expect(try readAsset(GraphvizPlugin(), GraphvizPlugin.vizScriptPath).contains("Viz.js \(GraphvizPlugin.vizVersion)"))
        #expect(try readAsset(GraphvizPlugin(), "assets/vendor/viz-\(GraphvizPlugin.vizVersion)/NOTICE.txt").contains("Eclipse Public License"))
    }
}

struct SyntaxHighlightingPluginTests {
    private let plugin = SyntaxHighlightingPlugin()

    @Test func renderingIsUnchangedAndKeepsLanguageClass() {
        #expect(render("```swift\nlet x = 1\n```", with: plugin) == "<pre><code class=\"language-swift\">let x = 1\n</code></pre>\n")
    }

    @Test func declaredAssetsAndBothThemesExist() {
        for path in plugin.previewAssets.map(\.relativePath) + [SyntaxHighlightingPlugin.lightThemePath, SyntaxHighlightingPlugin.darkThemePath] {
            #expect(assetExists(plugin, path))
        }
    }

    @Test func highlightJsLoadsBeforeBootstrapScript() throws {
        let paths = plugin.previewAssets.map(\.relativePath)
        #expect(try #require(paths.firstIndex(of: SyntaxHighlightingPlugin.highlightJSPath)) < #require(paths.firstIndex(of: SyntaxHighlightingPlugin.bootstrapScriptPath)))
    }

    @Test func bundledHighlightJsIsTheTargetedVersion() throws {
        #expect(try readAsset(plugin, SyntaxHighlightingPlugin.highlightJSPath).contains("Highlight.js v\(SyntaxHighlightingPlugin.highlightJSVersion)"))
    }

    @Test func bootstrapScriptReferencesTheVendoredThemeFolderAndSkipsTheSameLanguages() throws {
        let script = try readAsset(plugin, SyntaxHighlightingPlugin.bootstrapScriptPath)
        #expect(script.contains("vendor/highlightjs-\(SyntaxHighlightingPlugin.highlightJSVersion)/"))
        for language in SyntaxHighlightingPlugin.renderedByOtherPlugins { #expect(script.contains("'\(language)'")) }
    }
}

struct TocPluginTests {
    private func render(_ markdown: String) -> String { MarkdownEditorPluginsTests.render(markdown, with: TocPlugin()) }

    @Test(arguments: ["[TOC]", "[toc]", "[[_TOC_]]"])
    func markerRendersNestedListOfHeadingLinks(_ marker: String) {
        let html = render("# Title\n\n\(marker)\n\n## Setup\n\n### Install `tool`\n\n## Usage\n")
        #expect(html.contains("<nav class=\"table-of-contents\">\n<ul>\n<li><a href=\"#title\">Title</a><ul>\n"
            + "<li><a href=\"#setup\">Setup</a><ul>\n<li><a href=\"#install-tool\">Install tool</a></li>\n</ul>\n</li>\n"
            + "<li><a href=\"#usage\">Usage</a></li>\n</ul>\n</li>\n</ul>\n</nav>"))
        #expect(html.contains("<h3 id=\"install-tool\">"))
    }

    @Test func headingsAfterTheMarkerInContainersAndLevelJumpsAreIncluded() {
        let html = render("[TOC]\n\n### Deep first\n\n# Top\n\n> ## In quote\n")
        #expect(html.contains("<li><a href=\"#deep-first\">Deep first</a></li>"))
        #expect(html.contains("<li><a href=\"#top\">Top</a></li>\n<li><a href=\"#in-quote\">In quote</a></li>"))
        #expect(html.occurrences(of: "<ul>") == html.occurrences(of: "</ul>"))
    }

    @Test(arguments: ["See [TOC] here\n", "text\n[TOC]\n", "    [TOC]\n", "`[TOC]`\n", "> quote\n[TOC]\n"])
    func markerInsideTextOrCodeIsNotAToc(_ markdown: String) {
        #expect(!render(markdown).contains("table-of-contents"))
    }

    @Test func headingTextIsHtmlEscaped() {
        #expect(render("[TOC]\n\n# a < b & c\n").contains(">a &lt; b &amp; c</a>"))
    }

    @Test func entryLabelIsTheHeadingTextWithLineBreaksAsSpaces() {
        #expect(render("[TOC]\n\nOne *two*\n`three`\n===\n").contains("<a href=\"#one-twothree\">One two three</a>"))
    }

    @Test func emptyDocumentTocIsEmptyNav() {
        #expect(render("[TOC]\n") == "<nav class=\"table-of-contents\">\n</nav>\n")
    }

    @Test func declaredStylesheetExists() {
        #expect(assetExists(TocPlugin(), TocPlugin.stylesheetPath))
    }
}

struct FrontMatterPluginTests {
    private func render(_ markdown: String) -> String { MarkdownEditorPluginsTests.render(markdown, with: FrontMatterPlugin()) }

    @Test func frontMatterRendersAsTableAndBodyFollows() {
        let html = render("---\ntitle: Hello <World>\ntags: [a, \"b c\"]\ncreated: 2026-11-09\n---\n\n# Body\n")
        #expect(html.hasPrefix("<table class=\"front-matter\">"))
        #expect(html.contains("<th>title</th>"))
        #expect(html.contains("<td>Hello &lt;World&gt;</td>"))
        #expect(html.contains("<td><ul><li>a</li><li>b c</li></ul></td>"))
        #expect(html.contains("<td>2026-11-09</td>"))
        #expect(html.hasSuffix("</table>\n<h1>Body</h1>\n"))
        #expect(!html.contains("---"))
    }

    @Test(arguments: ["---\na: 1\n...\nbody\n", "--- \na: 1\n---  \nbody\n", "---\na: 1\n\n----\n---\nbody\n"])
    func frontMatterEndsAtThreeDashesOrDots(_ markdown: String) {
        #expect(render(markdown).hasSuffix("<td>1</td>\n</tr>\n</tbody>\n</table>\n<p>body</p>\n"))
    }

    @Test(arguments: ["Intro\n\n---\ntitle: x\n---\n", "\n---\ntitle: x\n---\n", "---\ntitle: x\nbody\n", " ---\ntitle: x\n---\n", "---\n---\ntitle: x\n", "---\n...\nx\n"])
    func frontMatterMustBeClosedAndAtTheVeryStart(_ markdown: String) {
        #expect(!render(markdown).contains("front-matter"))
    }

    @Test func frontMatterWithoutKeysRendersNothing() {
        #expect(render("---\n# only a comment\n---\nBody\n") == "<p>Body</p>\n")
        #expect(render("---\n\n---\nBody\n") == "<p>Body</p>\n")
        #expect(render("---\n---\n---\nBody\n") == "<hr />\n<p>Body</p>\n")
    }

    @Test func nestedMappingsAreShownAsRawYaml() {
        #expect(render("---\nauthor:\n  name: Me\n---\n").contains("<td><pre><code>name: Me</code></pre></td>"))
    }

    @Test func parsesScalarsQuotesCommentsBlockListsAndNestedMappings() {
        let entries = FrontMatterYAML.parse(
            "title: 'Quoted # not comment'\n" + "status: draft # a comment\n" + "tags:\n  - one\n  - two\n"
                + "author:\n  name: Me\n  email: me@example.org\n" + "empty:\n" + "# full line comment\n")
        #expect(entries == [
            FrontMatterEntry(key: "title", values: ["Quoted # not comment"]),
            FrontMatterEntry(key: "status", values: ["draft"]),
            FrontMatterEntry(key: "tags", values: ["one", "two"]),
            FrontMatterEntry(key: "author", values: ["name: Me\nemail: me@example.org"], isRaw: true),
            FrontMatterEntry(key: "empty", values: []),
        ])
    }

    @Test func declaredStylesheetExists() {
        #expect(assetExists(FrontMatterPlugin(), FrontMatterPlugin.stylesheetPath))
    }
}

struct WikiLinksPluginTests {
    private func render(_ markdown: String) -> String { MarkdownEditorPluginsTests.render(markdown, with: WikiLinksPlugin()) }

    @Test(arguments: [
        ("[[Note]]", "<a href=\"Note.md\" class=\"wikilink\">Note</a>"),
        ("[[My Note]]", "<a href=\"My%20Note.md\" class=\"wikilink\">My Note</a>"),
        ("[[folder/Note|the note]]", "<a href=\"folder/Note.md\" class=\"wikilink\">the note</a>"),
        ("[[Note#Setup]]", "<a href=\"Note.md\" class=\"wikilink\">Note &gt; Setup</a>"),
        ("[[Note#Setup|alias]]", "<a href=\"Note.md\" class=\"wikilink\">alias</a>"),
        ("[[diagram.png]]", "<a href=\"diagram.png\" class=\"wikilink\">diagram.png</a>"),
        ("[[../up]]", "<a href=\"../up.md\" class=\"wikilink\">../up</a>"),
        ("[[é]]", "<a href=\"%C3%A9.md\" class=\"wikilink\">é</a>"),
    ])
    func wikilinksRenderAsLinksToMarkdownFiles(markdown: String, link: String) {
        #expect(render("See \(markdown) now") == "<p>See \(link) now</p>\n")
    }

    @Test(arguments: ["[[]]", "[[|alias]]", "[[unclosed", "`[[Note]]`", "[[a\nb]]", "[[a[b]]"])
    func invalidOrCodeWikilinksAreNotLinks(_ markdown: String) {
        #expect(!render(markdown).contains("wikilink"))
    }

    @Test func standardLinksStillWork() {
        #expect(render("[x](a.md) and [[B]]") == "<p><a href=\"a.md\">x</a> and <a href=\"B.md\" class=\"wikilink\">B</a></p>\n")
    }

    @Test func declaredStylesheetExists() {
        #expect(assetExists(WikiLinksPlugin(), WikiLinksPlugin.stylesheetPath))
    }
}

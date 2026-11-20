import CommonMark
import Foundation
import Testing
import TestSupport
import MarkdownEditorCore
@testable import MarkdownEditorPlugins

struct AlertsPluginTests {
    private func render(_ markdown: String) -> String { MarkdownEditorPluginsTests.render(markdown, with: AlertsPlugin()) }

    @Test(arguments: [("NOTE", "note", "Note"), ("TIP", "tip", "Tip"), ("IMPORTANT", "important", "Important"), ("WARNING", "warning", "Warning"),
                      ("CAUTION", "caution", "Caution"), ("note", "note", "Note")])
    func gitHubAlertKindsRenderWithTitleAndIcon(kind: String, cssKind: String, title: String) {
        let html = render("> [!\(kind)]\n> Body text.\n")
        #expect(html.hasPrefix("<div class=\"markdown-alert markdown-alert-\(cssKind)\">\n<p class=\"markdown-alert-title\"><svg"))
        #expect(html.contains("</svg>\(title)</p>\n<p>Body text.</p>\n</div>\n"))
    }

    @Test func alertKeepsEveryBlockOfTheQuote() {
        let html = render("> [!IMPORTANT]  \n> a\n>\n> - b\n")
        #expect(html.contains("</svg>Important</p>\n<p>a</p>\n<ul>\n<li>b</li>\n</ul>\n</div>\n"))
    }

    @Test(arguments: ["> [!foo]\n> x\n", "> [!NOTEX]\n> x\n", "> just a quote\n", "> [!TIP] same line\n> more\n", "> text\n> [!NOTE]\n> x\n"])
    func otherBlockquotesStayBlockquotes(_ markdown: String) {
        let html = render(markdown)
        #expect(html.hasPrefix("<blockquote>"))
        #expect(!html.contains("markdown-alert"))
    }

    @Test(arguments: ["- item\n\n  > [!CAUTION]\n  > nested\n", "> > [!NOTE]\n> > x\n"])
    func nestedBlockquotesAreNotAlerts(_ markdown: String) {
        #expect(!render(markdown).contains("markdown-alert"))
    }

    @Test func alertCarriesTheSourceLinesOfTheQuote() {
        let html = MarkdownRenderer(plugins: [AlertsPlugin()]).renderDocument("> [!NOTE]\n> Body text.\n", annotateSourceLines: true).html
        #expect(html.hasPrefix("<div class=\"markdown-alert markdown-alert-note\" data-line=\"0\" data-line-end=\"1\">"))
    }

    @Test func declaredStylesheetExists() {
        #expect(assetExists(AlertsPlugin(), AlertsPlugin.stylesheetPath))
    }
}

struct EmojiPluginTests {
    private func render(_ markdown: String) -> String { MarkdownEditorPluginsTests.render(markdown, with: EmojiPlugin()) }

    @Test(arguments: [(":smile:", "😄"), (":+1:", "👍"), (":rocket:", "🚀"), (":white_check_mark:", "✅"), (":warning:", "⚠")])
    func gitHubShortcodesRenderAsUnicode(shortcode: String, emoji: String) {
        #expect(render("Done \(shortcode) now").range(of: emoji, options: .literal) != nil)
    }

    @Test(arguments: ["Happy :)", "Sad :(", ":not_a_real_shortcode:", "time 10:30:00", "a:smile:b", "\\:smile:"])
    func smileysUnknownCodesTimesAndEscapedCodesAreUnchanged(_ text: String) {
        #expect(render(text) == "<p>\(text.replacingOccurrences(of: "\\", with: ""))</p>\n")
    }

    @Test func shortcodesFollowPunctuationAndOtherEmoji() {
        #expect(render("(:smile:) :smile::+1: :smile:.") == "<p>(😄) 😄👍 😄.</p>\n")
    }

    @Test func shortcodesInCodeAreUnchanged() {
        #expect(render("`:smile:`") == "<p><code>:smile:</code></p>\n")
    }
}

struct FootnotesPluginTests {
    private func render(_ markdown: String) -> String { MarkdownEditorPluginsTests.render(markdown, with: FootnotesPlugin()) }

    @Test func referenceLinksToNumberedDefinitionWithBackLink() {
        let html = render("Claim[^note] and more[^2].\n\n[^note]: First source.\n[^2]: Second.\n")
        #expect(html.contains("<a id=\"fnref:1\" href=\"#fn:1\" class=\"footnote-ref\"><sup>1</sup></a>"))
        #expect(html.contains("<a id=\"fnref:2\" href=\"#fn:2\" class=\"footnote-ref\"><sup>2</sup></a>"))
        #expect(html.contains("<div class=\"footnotes\">\n<hr />\n<ol>\n<li id=\"fn:1\">\n<p>First source.<a href=\"#fnref:1\" class=\"footnote-back-ref\">&#8617;</a></p>\n</li>"))
        #expect(html.hasSuffix("</li>\n</ol>\n</div>\n"))
    }

    @Test func footnoteReferencedTwiceHasTwoBackLinksAndUnusedFootnotesAreDropped() {
        let html = render("Claim[^note] and more[^2] again[^note].\n\n[^note]: First source.\n[^2]: Second.\n[^unused]: Unused.\n")
        #expect(html.contains("again<a id=\"fnref:2\" href=\"#fn:1\" class=\"footnote-ref\"><sup>1</sup></a>"))
        #expect(html.contains("more<a id=\"fnref:3\" href=\"#fn:2\" class=\"footnote-ref\"><sup>2</sup></a>"))
        #expect(html.contains("First source.<a href=\"#fnref:1\" class=\"footnote-back-ref\">&#8617;</a><a href=\"#fnref:2\" class=\"footnote-back-ref\">&#8617;</a></p>"))
        #expect(!html.contains("Unused"))
    }

    @Test func multiParagraphDefinitionEndsWhereTheIndentationEnds() {
        let html = render("Text[^a].\n\n[^a]: Para one.\n\n    Para two.\n\nAfter.\n")
        #expect(html.contains("<p>After.</p>\n<div class=\"footnotes\">"))
        #expect(html.contains("<p>Para one.</p>\n<p>Para two.<a href"))
    }

    @Test func definitionHoldingBlocksGetsItsBackLinkInANewParagraph() {
        let html = render("x[^1]\n\n[^1]: - a\n    - b\n\n    ```\n    code\n    ```\n")
        #expect(html.contains("<li id=\"fn:1\">\n<ul>\n<li>a</li>\n<li>b</li>\n</ul>\n<pre><code>code\n</code></pre>\n<p><a href=\"#fnref:1\" class=\"footnote-back-ref\">&#8617;</a></p>\n</li>"))
    }

    @Test(arguments: ["Text[^missing].", "Text[^].", "Text[^a b]."])
    func undefinedOrMalformedReferenceStaysText(_ markdown: String) {
        #expect(render(markdown) == "<p>\(markdown)</p>\n")
    }

    @Test func documentWithoutReferencesHasNoFootnoteSection() {
        #expect(render("Text.\n\n[^a]: Unused.\n") == "<p>Text.</p>\n")
    }

    @Test func declaredStylesheetExists() {
        #expect(assetExists(FootnotesPlugin(), FootnotesPlugin.stylesheetPath))
    }
}

struct HeadingAnchorsPluginTests {
    private func render(_ markdown: String) -> String { MarkdownEditorPluginsTests.render(markdown, with: HeadingAnchorsPlugin()) }

    // Expected ids are the ones github.com generates for the same headings.
    @Test(arguments: [
        ("# Hello World", "hello-world"),
        ("## Agent session (conversation cache)", "agent-session-conversation-cache"),
        ("### What's new in v1.2?", "whats-new-in-v12"),
        ("## snake_case and kebab-case", "snake_case-and-kebab-case"),
        ("## `code` heading", "code-heading"),
        ("## Émoji & Ünïcode", "émoji--ünïcode"),
        ("## a_b *c* [d](e) ![f](g)", "a_b-c-d-f"),
        ("## 1.2 Thing-y / z", "12-thing-y--z"),
        ("##", "section"),
        ("Foo *bar\nbaz*\n====", "foo-barbaz"),
    ])
    func idsMatchGitHub(markdown: String, id: String) {
        #expect(render(markdown).contains("id=\"\(id)\""))
    }

    @Test func duplicateHeadingsAreSuffixed() {
        let html = render("## Setup\n\n## Setup\n\n> ## Setup\n")
        #expect(html.contains("id=\"setup\""))
        #expect(html.contains("id=\"setup-1\""))
        #expect(html.contains("id=\"setup-2\""))
    }

    @Test func declaredAssetsExist() {
        for asset in HeadingAnchorsPlugin().previewAssets { #expect(assetExists(HeadingAnchorsPlugin(), asset.relativePath)) }
    }
}

struct MathPluginTests {
    private func render(_ markdown: String) -> String { MarkdownEditorPluginsTests.render(markdown, with: MathPlugin()) }

    @Test(arguments: [
        ("$a<b$", "<span class=\"math\">\\(a&lt;b\\)</span>"),
        ("$`x^2`$", "<span class=\"math\">\\(x^2\\)</span>"),
        ("$\\sqrt{3x-1}+(1+x)^2$", "<span class=\"math\">\\(\\sqrt{3x-1}+(1+x)^2\\)</span>"),
        ("$$c$$", "<span class=\"math\">\\(c\\)</span>"),
        ("$ d $", "<span class=\"math\">\\(d\\)</span>"),
        ("$*a*$ $_b_$", "<span class=\"math\">\\(*a*\\)</span> <span class=\"math\">\\(_b_\\)</span>"),
        ("$$a$b$$", "<span class=\"math\">\\(a$b\\)</span>"),
        ("$\\$$", "<span class=\"math\">\\(\\$\\)</span>"),
        ("$x`y`$", "<span class=\"math\">\\(x`y`\\)</span>"),
        ("($k$).", "(<span class=\"math\">\\(k\\)</span>)."),
    ])
    func inlineMathIsMarkedForTypesetting(markdown: String, html: String) {
        #expect(render(markdown) == "<p>\(html)</p>\n")
    }

    @Test func blockMathIsMarkedForDisplayTypesetting() {
        #expect(render("$$\n\\sum_i x_i\n$$\n") == "<div class=\"math\">\n\\[\n\\sum_i x_i\n\\]</div>\n")
    }

    @Test func blockMathInterruptsAParagraphAndRunsToTheEndWhenUnclosed() {
        #expect(render("text\n$$\na\n$$\nafter\n") == "<p>text</p>\n<div class=\"math\">\n\\[\na\n\\]</div>\n<p>after</p>\n")
        #expect(render("$$\na < b\n") == "<div class=\"math\">\n\\[\na &lt; b\n\\]</div>\n")
        #expect(render("$$ x = 1 $$\n") == "<p><span class=\"math\">\\(x = 1\\)</span></p>\n")
    }

    @Test func mathFenceStaysALanguageMathCodeBlock() {
        #expect(render("```math\nE=mc^2\n```\n") == "<pre><code class=\"language-math\">E=mc^2\n</code></pre>\n")
    }

    @Test(arguments: [
        ("It costs $5 and $6.", "<p>It costs $5 and $6.</p>\n"),
        ("`$x$`", "<p><code>$x$</code></p>\n"),
        ("a$e$f and $g$5 and \\$h$", "<p>a$e$f and $g$5 and $h$</p>\n"),
        ("$i\nj$ and $a$b$ and $ x$", "<p>$i\nj$ and $a$b$ and $ x$</p>\n"),
    ])
    func currencyCodeAndUnbalancedDollarsAreNotMath(markdown: String, html: String) {
        #expect(render(markdown) == html)
    }

    @Test func declaredAssetsAndFontsExist() throws {
        for asset in MathPlugin().previewAssets { #expect(assetExists(MathPlugin(), asset.relativePath)) }
        let fonts = try FileManager.default.contentsOfDirectory(atPath: SharedFiles.pluginFile(MathPlugin.pluginID, MathPlugin.vendorFolder + "/fonts").path)
        #expect(fonts.contains { $0.hasSuffix(".woff2") })
    }

    @Test func bundledKatexIsTheTargetedVersionAndDoesNotNeedEval() throws {
        let script = try readAsset(MathPlugin(), MathPlugin.katexScriptPath)
        #expect(script.contains("\"\(MathPlugin.katexVersion)\""))
        #expect(!script.contains("new Function")) // the preview policy forbids eval
    }
}

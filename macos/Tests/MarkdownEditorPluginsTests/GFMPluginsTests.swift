import CommonMark
import Foundation
import Testing
import TestSupport
import MarkdownEditorCore
@testable import MarkdownEditorPlugins

struct TablesPluginTests {
    private func render(_ markdown: String) -> String { MarkdownEditorPluginsTests.render(markdown, with: TablesPlugin()) }

    @Test func pipeTableRendersWithHeaderBodyAndAlignment() {
        let html = render("| Turn | Name | Mid |\n| ---: | :--- | :---: |\n| 0 | a | x |\n| 1 | b | y |\n")
        #expect(html.contains("<thead>"))
        #expect(html.contains("<tbody>"))
        #expect(html.contains("<th align=\"right\">Turn</th>"))
        #expect(html.contains("<td align=\"left\">b</td>"))
        #expect(html.contains("<td align=\"center\">y</td>"))
        #expect(html.occurrences(of: "<tr>") == 3)
    }

    @Test func tableAfterParagraphAndHeadingRenders() {
        let html = render("### Title\n\nSome text.\n\n| a | b |\n| --- | --- |\n| 1 | 2 |\n")
        #expect(html.contains("<h3>Title</h3>"))
        #expect(html.contains("<table>"))
    }

    @Test(arguments: ["a | b\n", "| a | b |\n", "| a | b |\n| - |\n"])
    func pipesWithoutMatchingDelimiterRowAreNotATable(_ markdown: String) {
        #expect(!render(markdown).contains("<table>"))
    }

    @Test func earlierParagraphLinesStayAParagraph() {
        #expect(render("intro\n| a | b |\n| - | - |\n| 1 | 2 |\n").hasPrefix("<p>intro</p>\n<table>"))
    }

    @Test(arguments: [("> | a | b |\n> | - | - |\n> | 1 | 2 |\n", "<blockquote>\n<table>"), ("- item\n\n  | a | b |\n  | - | - |\n  | 1 | 2 |\n", "<table>")])
    func tablesNestInContainers(markdown: String, expected: String) {
        #expect(render(markdown).contains(expected))
    }

    @Test func headingEndsTheTable() {
        #expect(render("| a |\n| - |\n| 1 |\n## next\n").hasSuffix("</table>\n<h2>next</h2>\n"))
    }

    @Test func indentedDelimiterRowIsNotATable() {
        #expect(!render("| a | b |\n    | - | - |\n").contains("<table>"))
    }

    @Test func cellsHoldInlineContentAndEscapedPipes() {
        let html = render("| a | b |\n| - | - |\n| *x* `y\\|z` | [l](u) |\n")
        #expect(html.contains("<td><em>x</em> <code>y|z</code></td>"))
        #expect(html.contains("<td><a href=\"u\">l</a></td>"))
    }

    @Test func rowsCarryTheirSourceLines() {
        let html = MarkdownRenderer(plugins: [TablesPlugin()]).renderDocument("intro\n| a |\n| - |\n| 1 |\n| 2 |\n", annotateSourceLines: true).html
        #expect(html.contains("<p data-line=\"0\" data-line-end=\"0\">intro</p>"))
        #expect(html.contains("<table data-line=\"1\" data-line-end=\"4\">"))
        #expect(html.contains("<tr data-line=\"1\" data-line-end=\"1\">"))
        #expect(html.contains("<tr data-line=\"4\" data-line-end=\"4\">"))
    }

    @Test(arguments: GFMSpecExample.examples(for: "table"))
    func gfmSpecTableExamples(_ example: GFMSpecExample) {
        #expect(SpecHTML.normalize(render(example.markdown)) == SpecHTML.normalize(example.html))
    }

    @Test func declaredStylesheetExists() {
        #expect(assetExists(TablesPlugin(), TablesPlugin.stylesheetPath))
    }
}

struct TaskListsPluginTests {
    private func render(_ markdown: String) -> String { MarkdownEditorPluginsTests.render(markdown, with: TaskListsPlugin()) }

    // GFM spec 0.29 examples 279 and 280 (task list items extension; disabled in cmark-gfm's suite,
    // so the expected checkbox markup is the Windows app's equivalent of GitHub's).
    @Test func uncheckedAndCheckedItemsRenderAsDisabledCheckboxes() {
        let html = render("- [ ] foo\n- [x] bar\n- [X] baz\n")
        #expect(html.contains("<ul class=\"contains-task-list\">"))
        #expect(html.contains("<li class=\"task-list-item\"><input disabled=\"disabled\" type=\"checkbox\" /> foo</li>"))
        #expect(html.contains("<li class=\"task-list-item\"><input disabled=\"disabled\" type=\"checkbox\" checked=\"checked\" /> bar</li>"))
        #expect(html.contains("checked=\"checked\" /> baz"))
    }

    @Test func nestedOrderedLooseAndEmptyTaskItemsRender() {
        #expect(render("- [x] foo\n  - [ ] bar\n  - [x] baz\n- [ ] bim\n").occurrences(of: "type=\"checkbox\"") == 4)
        #expect(render("1. [ ] one\n").contains("<ol class=\"contains-task-list\">"))
        #expect(render("- [x] *em*\n\n  para\n").contains("<p><input disabled=\"disabled\" type=\"checkbox\" checked=\"checked\" /> <em>em</em></p>"))
        #expect(render("- [ ]\n").contains("type=\"checkbox\""))
    }

    @Test(arguments: ["[ ] not a list item\n", "- [] missing space\n", "- [y] other letter\n", "- text [x] in the middle\n", "- [x]no space after\n"])
    func bracketsOutsideTaskListSyntaxStayText(_ markdown: String) {
        #expect(!render(markdown).contains("checkbox"))
    }

    @Test func declaredStylesheetExists() {
        #expect(assetExists(TaskListsPlugin(), TaskListsPlugin.stylesheetPath))
    }
}

struct StrikethroughPluginTests {
    private func render(_ markdown: String) -> String { MarkdownEditorPluginsTests.render(markdown, with: StrikethroughPlugin()) }

    @Test(arguments: GFMSpecExample.examples(for: "strikethrough"))
    func gfmSpecStrikethroughExamples(_ example: GFMSpecExample) {
        #expect(SpecHTML.normalize(render(example.markdown)) == SpecHTML.normalize(example.html))
    }

    @Test(arguments: [
        ("~one~", "<p><del>one</del></p>\n"),
        ("a ~~b **c**~~ d", "<p>a <del>b <strong>c</strong></del> d</p>\n"),
        ("~~a ~~b~~ c~~", "<p><del>a <del>b</del> c</del></p>\n"),
        ("~~~a~~~ b", "<p>~~~a~~~ b</p>\n"),
        ("~~a~ b", "<p>~~a~ b</p>\n"),
    ])
    func tildeRunsOfTheSameLengthStrikeThrough(markdown: String, html: String) {
        #expect(render("x " + markdown) == "<p>x " + html.dropFirst(3))
    }

    @Test(arguments: ["H~2~O", "x^2^", "==mark==", "++ins++"])
    func otherEmphasisExtrasAreNotEnabled(_ markdown: String) {
        #expect(render(markdown) == "<p>\(markdown)</p>\n")
    }
}

struct AutolinksPluginTests {
    private func render(_ markdown: String) -> String { MarkdownEditorPluginsTests.render(markdown, with: AutolinksPlugin()) }

    @Test(arguments: GFMSpecExample.examples(for: "autolink"))
    func gfmSpecAutolinkExamples(_ example: GFMSpecExample) {
        #expect(SpecHTML.normalize(render(example.markdown)) == SpecHTML.normalize(example.html))
    }

    @Test(arguments: [
        ("[www.example.com](http://x.org)", "<p><a href=\"http://x.org\">www.example.com</a></p>\n"),
        ("![www.example.com](a.png)", "<p><img src=\"a.png\" alt=\"www.example.com\" /></p>\n"),
        ("`www.example.com`", "<p><code>www.example.com</code></p>\n"),
        ("xwww.example.com", "<p>xwww.example.com</p>\n"),
        ("www.a_b.c_d", "<p>www.a_b.c_d</p>\n"),
    ])
    func existingLinksCodeAndNonBoundariesAreLeftAlone(markdown: String, html: String) {
        #expect(render(markdown) == html)
    }

    @Test func autolinkInsideEmphasisAndWithUnderscoresInPath() {
        #expect(render("*www.example.com*") == "<p><em><a href=\"http://www.example.com\">www.example.com</a></em></p>\n")
        #expect(render("see www.example.com/a_b_c now").contains("href=\"http://www.example.com/a_b_c\""))
    }

    @Test(arguments: ["*a* www.example.com", "*a* www.example.com *b*", "www.example.com *a*"])
    func rewrittenParagraphKeepsAConsistentInlineTree(_ markdown: String) {
        let builder = MarkdownPipelineBuilder()
        AutolinksPlugin().configurePipeline(builder)
        let document = builder.build().parse(markdown)
        // Tree walks (used by later processing and usage probes) must see every node, not only the new ones.
        #expect(document.descendants(ofType: Emphasis.self).count == markdown.occurrences(of: "*") / 2)
        #expect(document.descendants(ofType: Link.self).count == 1)
    }

    @Test func scannerReportsPositionsAndTargets() {
        #expect(GFMAutolinkScanner.scan("é www.a.bc, me@x.org.") == [
            AutolinkMatch(start: 2, length: 8, url: "http://www.a.bc"),
            AutolinkMatch(start: 12, length: 8, url: "mailto:me@x.org"),
        ])
    }
}

struct TagFilterPluginTests {
    private func render(_ markdown: String) -> String { MarkdownEditorPluginsTests.render(markdown, with: TagFilterPlugin()) }

    @Test(arguments: GFMSpecExample.examples(for: "tagfilter"))
    func gfmSpecTagFilterExamples(_ example: GFMSpecExample) {
        #expect(SpecHTML.normalize(render(example.markdown)) == SpecHTML.normalize(example.html))
    }

    @Test(arguments: [
        ("<script>x</script>\n", "&lt;script>x&lt;/script>\n"),
        ("a <IFRAME src=x> b\n", "<p>a &lt;IFRAME src=x> b</p>\n"),
        ("<div><style>p{}</style></div>\n", "<div>&lt;style>p{}&lt;/style></div>\n"),
    ])
    func disallowedTagsAreEscapedInHtmlBlocksAndInlines(markdown: String, html: String) {
        #expect(render(markdown) == html)
    }

    @Test(arguments: [
        ("<div class=\"x\">ok</div>\n", "<div class=\"x\">ok</div>\n"),
        ("<titles>\n", "<titles>\n"),
        ("`<script>`\n", "<p><code>&lt;script&gt;</code></p>\n"),
    ])
    func otherTagsAndCodeAreUnchanged(markdown: String, html: String) {
        #expect(render(markdown) == html)
    }
}

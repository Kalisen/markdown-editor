import Testing
import MarkdownEditorCore
@testable import MarkdownEditorPlugins

/// All bundled plugins configured together, as in the app.
struct AllPluginsTests {
    private static let renderer = MarkdownRenderer(plugins: BundledPlugins.all)

    @Test func allBundledPluginsLoadConfigureAndReportUsage() {
        #expect(BundledPlugins.all.count == 17)
        #expect(Self.renderer.failures.isEmpty)
        #expect(Self.renderer.activePlugins.count == 17)
        #expect(BundledPlugins.all.allSatisfy { $0 is DocumentFeatureProbe })
        #expect(BundledPlugins.all.allSatisfy { PluginID.isValid($0.id) })
        #expect(Set(BundledPlugins.all.map(\.id)).count == 17)
    }

    @Test func everyDeclaredPreviewAssetExists() {
        for plugin in BundledPlugins.all {
            for asset in plugin.previewAssets { #expect(assetExists(plugin, asset.relativePath), "\(plugin.id): \(asset.relativePath)") }
        }
    }

    @Test(arguments: [
        ("images", "![x](a.png)"),
        ("mermaid", "```mermaid\ngraph TD\nA-->B\n```"),
        ("tables", "| a | b |\n| - | - |\n| 1 | 2 |"),
        ("task-lists", "- [ ] todo"),
        ("strikethrough", "~~gone~~"),
        ("autolinks", "see www.example.com"),
        ("tag-filter", "<script>x</script>"),
        ("footnotes", "x[^1]\n\n[^1]: note"),
        ("alerts", "> [!NOTE]\n> hi"),
        ("heading-anchors", "# Title"),
        ("emoji", "go :rocket:"),
        ("syntax-highlighting", "```csharp\nvar x = 1;\n```"),
        ("math", "$x^2$"),
        ("toc", "[TOC]"),
        ("front-matter", "---\ntitle: x\n---\nbody"),
        ("wikilinks", "[[Note]]"),
        ("graphviz", "```dot\ndigraph { a -> b }\n```"),
    ])
    func eachPluginIsReportedOnlyWhenItsSyntaxIsUsed(id: String, markdown: String) {
        let used = Self.renderer.renderDocument(markdown).usedPlugins.map(\.id)
        #expect(used.contains(id))
        // Heading anchors also apply wherever there is a heading; the TOC adds heading ids itself.
        #expect(used.allSatisfy { $0 == id || id == "heading-anchors" }, "\(used) reported for \(id)")
    }

    @Test(arguments: ["Just a paragraph with *emphasis*, `code` and a [link](https://x.org).", "```\nplain code\n```", "> quote\n\n- item", "<https://x.org> <me@x.org>"])
    func plainCommonMarkUsesNoExtension(_ markdown: String) {
        #expect(Self.renderer.renderDocument(markdown).usedPlugins.isEmpty)
    }

    @Test func pluginsCoexistInOneDocument() {
        let result = Self.renderer.renderDocument(
            "---\ntitle: All\n---\n# Doc :rocket:\n\n[TOC]\n\n- [x] ~~done~~ www.x.org\n\n| a |\n| - |\n| $y$ |\n\n"
                + "> [!TIP]\n> See [[Other]][^n].\n\n```mermaid\ngraph TD\nA-->B\n```\n\n```python\nprint(1)\n```\n\n[^n]: note\n")
        #expect(result.usedPlugins.map(\.id).sorted() == ["alerts", "autolinks", "emoji", "footnotes", "front-matter", "heading-anchors", "math", "mermaid",
                                                           "strikethrough", "syntax-highlighting", "tables", "task-lists", "toc", "wikilinks"])
        #expect(result.html.contains("<table class=\"front-matter\">"))
        #expect(result.html.contains("<nav class=\"table-of-contents\">"))
        #expect(result.html.contains("<td><span class=\"math\">"))
        #expect(result.html.contains("class=\"wikilink\""))
        #expect(result.html.contains("<li class=\"task-list-item\"><input disabled=\"disabled\" type=\"checkbox\" checked=\"checked\" /> <del>done</del> <a href=\"http://www.x.org\">www.x.org</a></li>"))
        #expect(result.html.contains("<div class=\"markdown-alert markdown-alert-tip\">"))
        #expect(result.html.contains("<h1 id=\"doc-\">Doc 🚀</h1>"))
    }

    @Test func allPluginsStillRenderTheCommonMarkSamplesUnchanged() {
        #expect(Self.renderer.render("Setext\n===\n\n1. a\n2. b\n\n***\n\n    code\n") == "<h1 id=\"setext\">Setext</h1>\n<ol>\n<li>a</li>\n<li>b</li>\n</ol>\n<hr />\n<pre><code>code\n</code></pre>\n")
    }
}

import Foundation
import Testing
@testable import MarkdownEditorCore

struct PluginCatalogTests {
    @Test func validUniquePluginsAreAcceptedInvalidAndDuplicateIdsRejected() {
        var builder = PluginCatalogBuilder()
        builder.add(FakePlugin(id: "mermaid"), folder: URL(fileURLWithPath: "/f1"), source: "a")
        builder.add(FakePlugin(id: "mermaid"), folder: URL(fileURLWithPath: "/f2"), source: "b")
        builder.add(FakePlugin(id: "Bad_Id"), folder: URL(fileURLWithPath: "/f3"), source: "c")
        let catalog = builder.build()
        #expect(catalog.plugins.map(\.folder.path) == ["/f1"])
        #expect(catalog.failures.map(\.source) == ["b", "c"])
    }

    @Test func bundledPluginsAreServedFromAFolderNamedByTheirId() {
        let catalog = PluginCatalog(bundled: [FakePlugin(id: "tables"), FakePlugin(id: "tables")], pluginsFolder: URL(fileURLWithPath: "/shared/plugins"))
        #expect(catalog.plugins.map(\.folder.path) == ["/shared/plugins/tables"])
        #expect(catalog.failures == [PluginLoadFailure(source: "tables", reason: "Duplicate plugin id 'tables'.")])
    }

    @Test(arguments: [("images", true), ("my-plugin2", true), ("", false), ("Upper", false), ("-lead", false), ("a--b", false), ("dot.ted", false),
                      (String(repeating: "a", count: 41), false)])
    func pluginIdRules(id: String, valid: Bool) {
        #expect(PluginID.isValid(id) == valid)
    }
}

struct PluginUsageTextTests {
    private let tables = FakePlugin(id: "tables")
    private let math = FakePlugin(id: "math")
    private let emoji = FakePlugin(id: "emoji")

    @Test func describeListsUsedExtensionsAlphabetically() {
        #expect(PluginUsageText.describe([tables, math]) == "Extensions: math · tables")
    }

    @Test func describeWithoutExtensionsSaysCommonMarkOnly() {
        #expect(PluginUsageText.describe([]) == "Extensions: none (CommonMark only)")
    }

    @Test func detailsMarksUsedPluginsAmongLoadedOnes() {
        #expect(PluginUsageText.details(loaded: [tables, math, emoji], used: [math]) == "○ emoji\n● math\n○ tables")
    }
}

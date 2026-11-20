import Foundation

/// A plugin and the folder holding its files, served to the preview for its assets.
public struct LoadedPlugin {
    public let plugin: MarkdownPlugin
    public let folder: URL

    public init(plugin: MarkdownPlugin, folder: URL) {
        self.plugin = plugin
        self.folder = folder
    }
}

public struct PluginLoadFailure: Equatable {
    public let source: String
    public let reason: String

    public init(source: String, reason: String) {
        self.source = source
        self.reason = reason
    }
}

/// Outcome of plugin registration: plugins that were accepted, and those that were skipped.
public struct PluginCatalog {
    public let plugins: [LoadedPlugin]
    public let failures: [PluginLoadFailure]

    /// Registers plugins compiled into the app; each plugin's assets are in `<pluginsFolder>/<plugin id>`.
    public init(bundled plugins: [MarkdownPlugin], pluginsFolder: URL) {
        var builder = PluginCatalogBuilder()
        for plugin in plugins {
            builder.add(plugin, folder: pluginsFolder.appendingPathComponent(plugin.id, isDirectory: true), source: plugin.id)
        }
        self = builder.build()
    }

    init(plugins: [LoadedPlugin], failures: [PluginLoadFailure]) {
        self.plugins = plugins
        self.failures = failures
    }
}

/// Accumulates plugins, rejecting invalid or duplicate identifiers.
struct PluginCatalogBuilder {
    private var plugins: [LoadedPlugin] = []
    private var failures: [PluginLoadFailure] = []
    private var ids = Set<String>()

    mutating func add(_ plugin: MarkdownPlugin, folder: URL, source: String) {
        if !PluginID.isValid(plugin.id) {
            failures.append(PluginLoadFailure(source: source, reason: "Invalid plugin id '\(plugin.id)'."))
        } else if !ids.insert(plugin.id).inserted {
            failures.append(PluginLoadFailure(source: source, reason: "Duplicate plugin id '\(plugin.id)'."))
        } else {
            plugins.append(LoadedPlugin(plugin: plugin, folder: folder))
        }
    }

    func build() -> PluginCatalog {
        PluginCatalog(plugins: plugins, failures: failures)
    }
}

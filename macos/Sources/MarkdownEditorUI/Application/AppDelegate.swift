import AppKit
import MarkdownEditorCore
import MarkdownEditorPlugins

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let logger = Diagnostics.logger(category: "Application")

    private var controller: MainWindowController?
    private var openedFileAtLaunch = false

    /// The window exists before files passed at launch are opened.
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        NSApp.mainMenu = MainMenu.make()

        guard let assets = SharedAssets.locate() else {
            Self.logger.error("Shared preview resources not found in the app bundle nor in \(SharedAssets.environmentVariable, privacy: .public)")
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "\(MainWindowController.appTitle) cannot start"
            alert.informativeText = "Its preview resources are missing. Reinstall the app, or set \(SharedAssets.environmentVariable) to the repository's 'shared' folder."
            alert.runModal()
            NSApp.terminate(nil)
            return
        }

        let catalog = PluginCatalog(bundled: BundledPlugins.all, pluginsFolder: assets.pluginsFolder)
        let renderer = MarkdownRenderer(plugins: catalog.plugins.map(\.plugin))
        let activeIDs = Set(renderer.activePlugins.map(\.id))
        let prompts = AppKitUserPrompts()
        let session = EditorSession(store: FileDocumentStore(), prompts: prompts, watcher: FileDocumentWatcher())
        controller = MainWindowController(
            session: session, prompts: prompts, renderer: renderer,
            plugins: catalog.plugins.filter { activeIDs.contains($0.plugin.id) },
            failures: catalog.failures + renderer.failures, previewFolder: assets.previewFolder)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        // `MarkdownEditor notes.md` from a terminal: the file is a plain argument, not an open-document event.
        if !openedFileAtLaunch, let file = Self.fileArgument(CommandLine.arguments) { controller?.open(file) }
    }

    /// Files opened from Finder or the Dock. The editor shows one document: the first file.
    func application(_ application: NSApplication, open urls: [URL]) {
        openedFileAtLaunch = true
        controller?.window?.makeKeyAndOrderFront(nil)
        controller?.open(urls.first)
    }

    /// The first command-line argument that is not an option (`-NSSomething value` pairs are AppKit's).
    static func fileArgument(_ arguments: [String]) -> URL? {
        var index = 1
        while index < arguments.count {
            if arguments[index].hasPrefix("-") {
                index += 2
                continue
            }
            return URL(fileURLWithPath: arguments[index])
        }
        return nil
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        controller?.confirmClose() ?? true ? .terminateNow : .terminateCancel
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}

import AppKit

/// Entry point of the macOS app.
public enum MarkdownEditorApplication {
    @MainActor
    public static func run() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { application.run() }
    }
}

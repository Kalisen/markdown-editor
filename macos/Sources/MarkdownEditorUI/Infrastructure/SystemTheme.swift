import AppKit
import MarkdownEditorCore

/// The macOS appearance (light/dark) as a preview theme.
enum SystemTheme {
    static var current: PreviewTheme {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
    }
}

import MarkdownEditorUI

// The process starts on the main thread, which is the main actor's executor.
MainActor.assumeIsolated {
    MarkdownEditorApplication.run()
}

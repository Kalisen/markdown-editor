import os

/// Unified logging of the app (Console.app, `log stream --predicate 'subsystem == "io.github.kalisen.markdown-editor"'`).
public enum Diagnostics {
    public static let subsystem = "io.github.kalisen.markdown-editor"

    public static func logger(category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }
}

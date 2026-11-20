import Foundation

/// Renders off the calling (UI) thread and keeps only the latest request: a render that finishes after a
/// newer one was requested yields nil so stale output is never displayed.
public final class BackgroundRenderer<Output>: @unchecked Sendable {
    /// Deeply nested documents recurse deeply: the default stack of a secondary thread is too small for them.
    private static var stackSize: Int { 32 << 20 }

    private let render: (String) -> Output
    private let lock = NSLock()
    private var latest = 0

    public init(render: @escaping (String) -> Output) {
        self.render = render
    }

    /// - Returns: the result, or nil when superseded by a newer request.
    public func render(_ markdown: String) async -> Output? {
        let request = lock.withLock { () -> Int in
            latest += 1
            return latest
        }
        let output: Output = await withCheckedContinuation { continuation in
            let thread = Thread { continuation.resume(returning: self.render(markdown)) }
            thread.stackSize = Self.stackSize
            thread.name = "markdown-editor.render"
            thread.start()
        }
        return lock.withLock { request == latest } ? output : nil
    }
}

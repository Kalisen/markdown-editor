import Foundation

/// Signals that the watched document file may have been modified by another program.
public protocol DocumentWatcher: AnyObject {
    /// Called when the watched file was touched. It is only a hint: it also fires for the app's own saves
    /// and may fire several times per change, on any thread.
    var onChange: (() -> Void)? { get set }

    /// Watches `file` instead of the previous file; nil stops watching.
    func watch(_ file: URL?)
}

/// Watches the document file through file system events. The folder is watched too because many programs
/// save by writing a temporary file and renaming it over the original.
public final class FileDocumentWatcher: DocumentWatcher {
    private static let logger = Diagnostics.logger(category: "Documents")

    public var onChange: (() -> Void)?

    private let queue = DispatchQueue(label: "markdown-editor.document-watcher")
    private var file: URL?
    private var fileSource: DispatchSourceFileSystemObject?
    private var folderSource: DispatchSourceFileSystemObject?
    /// Identity of the file being watched, to tell a replaced file from changes to its siblings.
    private var fileIdentity: UInt64?

    public init() {}

    deinit {
        fileSource?.cancel()
        folderSource?.cancel()
    }

    public func watch(_ file: URL?) {
        queue.sync {
            fileSource?.cancel()
            folderSource?.cancel()
            fileSource = nil
            folderSource = nil
            fileIdentity = nil
            self.file = file
            guard let file else { return }
            folderSource = makeSource(for: file.deletingLastPathComponent(), events: [.write]) { [weak self] in self?.folderChanged() }
            watchFile()
        }
    }

    private func watchFile() {
        fileSource?.cancel()
        fileSource = nil
        guard let file else { return }
        fileIdentity = Self.identity(of: file)
        fileSource = makeSource(for: file, events: [.write, .extend, .delete, .rename]) { [weak self] in self?.fileChanged() }
    }

    private func fileChanged() {
        // A deleted or renamed file no longer receives events: follow whatever is at the path now.
        if let source = fileSource, !source.data.isDisjoint(with: [.delete, .rename]) { watchFile() }
        onChange?()
    }

    private func folderChanged() {
        guard let file, Self.identity(of: file) != fileIdentity else { return } // a sibling changed
        watchFile()
        onChange?()
    }

    private func makeSource(for url: URL, events: DispatchSource.FileSystemEvent, handler: @escaping () -> Void) -> DispatchSourceFileSystemObject? {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else {
            // Gone or unreadable: changes are then only noticed when the app checks on its own.
            Self.logger.debug("Cannot watch \(url.path, privacy: .public): \(String(cString: strerror(errno)), privacy: .public)")
            return nil
        }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: events, queue: queue)
        source.setEventHandler(handler: handler)
        source.setCancelHandler { close(descriptor) }
        source.resume()
        return source
    }

    private static func identity(of file: URL) -> UInt64? {
        var information = stat()
        return stat(file.path, &information) == 0 ? UInt64(information.st_ino) : nil
    }
}

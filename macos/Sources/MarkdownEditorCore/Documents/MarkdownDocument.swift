import CryptoKit
import Foundation

/// An open Markdown document. `fileURL` is nil until first saved.
public final class MarkdownDocument {
    public static let untitledName = "Untitled"

    public private(set) var fileURL: URL?
    public private(set) var isDirty = false

    // The saved state is kept as a fingerprint rather than a second full copy of the text.
    private var savedFingerprint: SHA256.Digest

    public init(fileURL: URL? = nil, text: String = "") {
        self.fileURL = fileURL
        self.text = text
        savedFingerprint = Self.fingerprint(text)
    }

    public var text: String {
        didSet { isDirty = !matchesSaved(text) }
    }

    public var displayName: String { fileURL?.lastPathComponent ?? Self.untitledName }

    /// The folder holding the document's file.
    public var folder: URL? { fileURL?.deletingLastPathComponent() }

    /// True when `text` is what was last loaded from or saved to the file.
    public func matchesSaved(_ text: String) -> Bool {
        Self.fingerprint(text) == savedFingerprint
    }

    public func markSaved(at fileURL: URL) {
        self.fileURL = fileURL
        savedFingerprint = Self.fingerprint(text)
        isDirty = false
    }

    /// Records that the file now holds `diskText` while this document keeps its own text:
    /// the document is dirty for as long as it differs from the file.
    public func markChangedOnDisk(_ diskText: String) {
        savedFingerprint = Self.fingerprint(diskText)
        isDirty = !matchesSaved(text)
    }

    private static func fingerprint(_ text: String) -> SHA256.Digest {
        SHA256.hash(data: Data(text.utf8))
    }
}

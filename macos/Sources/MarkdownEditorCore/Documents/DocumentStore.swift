import Foundation

public protocol DocumentStore {
    func read(_ url: URL) throws -> String

    func write(_ text: String, to url: URL) throws
}

/// Reads with byte order mark detection (UTF-8 by default); writes UTF-8 without a mark. Line endings are preserved.
public struct FileDocumentStore: DocumentStore {
    private static let utf8Mark: [UInt8] = [0xEF, 0xBB, 0xBF]
    private static let utf16LittleEndianMark: [UInt8] = [0xFF, 0xFE]
    private static let utf16BigEndianMark: [UInt8] = [0xFE, 0xFF]

    public init() {}

    public func read(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        if data.starts(with: Self.utf8Mark) { return String(decoding: data.dropFirst(Self.utf8Mark.count), as: UTF8.self) }
        if data.starts(with: Self.utf16LittleEndianMark) { return Self.decodeUTF16(data.dropFirst(2), littleEndian: true) }
        if data.starts(with: Self.utf16BigEndianMark) { return Self.decodeUTF16(data.dropFirst(2), littleEndian: false) }
        return String(decoding: data, as: UTF8.self)
    }

    public func write(_ text: String, to url: URL) throws {
        try Data(text.utf8).write(to: url, options: .atomic)
    }

    private static func decodeUTF16(_ data: Data, littleEndian: Bool) -> String {
        var units: [UInt16] = []
        units.reserveCapacity(data.count / 2)
        var iterator = data.makeIterator()
        while let first = iterator.next(), let second = iterator.next() {
            units.append(littleEndian ? UInt16(first) | UInt16(second) << 8 : UInt16(first) << 8 | UInt16(second))
        }
        return String(decoding: units, as: UTF16.self)
    }
}

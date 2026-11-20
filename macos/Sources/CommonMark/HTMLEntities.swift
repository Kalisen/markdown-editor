/// HTML character references: `&name;`, `&#123;` and `&#x1F;`.
public enum HTMLEntities {
    private static let named: [String: String] = {
        var table: [String: String] = [:]
        table.reserveCapacity(2200)
        for entry in namedTable.split(separator: ";") {
            guard let separator = entry.firstIndex(of: "=") else { continue }
            var text = ""
            for code in entry[entry.index(after: separator)...].split(separator: ",") {
                if let value = UInt32(code, radix: 16), let scalar = Unicode.Scalar(value) { text.unicodeScalars.append(scalar) }
            }
            table[String(entry[..<separator])] = text
        }
        return table
    }()

    /// The text of a named reference (without `&` and `;`), or nil when the name is not defined.
    public static func named(_ name: String) -> String? { named[name] }

    /// The text of a numeric reference; invalid code points become U+FFFD.
    static func numeric(_ value: UInt32) -> String {
        guard value != 0, let scalar = Unicode.Scalar(value) else { return "\u{FFFD}" }
        return String(Character(scalar))
    }

    /// Scans a character reference starting at the `&` at `start`.
    /// - Returns: the decoded text and the index after the `;`, or nil when there is no valid reference.
    static func scan(_ bytes: [UInt8], at start: Int) -> (text: String, end: Int)? {
        guard bytes.at(start) == Byte.ampersand else { return nil }
        var position = start + 1
        if bytes.at(position) == Byte.hash {
            position += 1
            let isHex = bytes.at(position).map { $0 | 0x20 } == UInt8(ascii: "x")
            if isHex { position += 1 }
            let digitsStart = position
            let maxDigits = isHex ? 6 : 7
            var value: UInt32 = 0
            while let byte = bytes.at(position), isHex ? Byte.isHexDigit(byte) : Byte.isDigit(byte), position - digitsStart < maxDigits {
                let digit = UInt32(Byte.isDigit(byte) ? byte - 0x30 : (byte | 0x20) - 0x61 + 10)
                value = value * (isHex ? 16 : 10) + digit
                position += 1
            }
            guard position > digitsStart, bytes.at(position) == Byte.semicolon else { return nil }
            return (numeric(value), position + 1)
        }
        let nameStart = position
        while let byte = bytes.at(position), Byte.isAlphanumeric(byte), position - nameStart < 32 { position += 1 }
        guard position > nameStart, bytes.at(position) == Byte.semicolon,
              let text = named(bytes.string(nameStart..<position)) else { return nil }
        return (text, position + 1)
    }
}

/// Escaping of text written into HTML.
public enum HTMLEscaping {
    /// Escapes `&`, `<`, `>` and `"`.
    public static func escape(_ text: String) -> String {
        var needsEscaping = false
        for byte in text.utf8 where byte == Byte.ampersand || byte == Byte.lessThan || byte == Byte.greaterThan || byte == Byte.doubleQuote {
            needsEscaping = true
            break
        }
        guard needsEscaping else { return text }
        var result: [UInt8] = []
        result.reserveCapacity(text.utf8.count + 16)
        for byte in text.utf8 {
            switch byte {
            case Byte.ampersand: result.append(contentsOf: "&amp;".utf8)
            case Byte.lessThan: result.append(contentsOf: "&lt;".utf8)
            case Byte.greaterThan: result.append(contentsOf: "&gt;".utf8)
            case Byte.doubleQuote: result.append(contentsOf: "&quot;".utf8)
            default: result.append(byte)
            }
        }
        return result.string
    }
}

/// Backslash escapes and character references inside link destinations, titles and info strings.
enum Unescaping {
    static func unescape(_ bytes: [UInt8]) -> String {
        guard bytes.contains(Byte.backslash) || bytes.contains(Byte.ampersand) else { return bytes.string }
        var result: [UInt8] = []
        result.reserveCapacity(bytes.count)
        var position = 0
        while position < bytes.count {
            let byte = bytes[position]
            if byte == Byte.backslash, let following = bytes.at(position + 1), Byte.isPunctuation(following) {
                result.append(following)
                position += 2
            } else if byte == Byte.ampersand, let entity = HTMLEntities.scan(bytes, at: position) {
                result.append(contentsOf: entity.text.utf8)
                position = entity.end
            } else {
                result.append(byte)
                position += 1
            }
        }
        return result.string
    }
}

/// Percent-encoding of link destinations: existing escapes are kept, unsafe characters are encoded.
public enum LinkDestination {
    private static let safe: [Bool] = {
        var table = [Bool](repeating: false, count: 128)
        for byte in ";/?:@&=+$,-_.!~*'()#".utf8 { table[Int(byte)] = true }
        for byte in UInt8(0)..<128 where Byte.isAlphanumeric(byte) { table[Int(byte)] = true }
        return table
    }()

    private static let hexDigits = Array("0123456789ABCDEF".utf8)

    public static func normalize(_ destination: String) -> String {
        let bytes = Array(destination.utf8)
        var result: [UInt8] = []
        result.reserveCapacity(bytes.count)
        var position = 0
        while position < bytes.count {
            let byte = bytes[position]
            if byte == UInt8(ascii: "%"), let first = bytes.at(position + 1), let second = bytes.at(position + 2),
               Byte.isHexDigit(first), Byte.isHexDigit(second) {
                result.append(contentsOf: bytes[position..<(position + 3)])
                position += 3
                continue
            }
            if byte < 128, safe[Int(byte)] {
                result.append(byte)
            } else {
                result.append(UInt8(ascii: "%"))
                result.append(hexDigits[Int(byte >> 4)])
                result.append(hexDigits[Int(byte & 0x0F)])
            }
            position += 1
        }
        return result.string
    }
}

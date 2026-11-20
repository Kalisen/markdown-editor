/// Byte-level character classes used by the parsers (the input is processed as UTF-8).
enum Byte {
    static let tab: UInt8 = 0x09
    static let newline: UInt8 = 0x0A
    static let carriageReturn: UInt8 = 0x0D
    static let space: UInt8 = 0x20
    static let bang = UInt8(ascii: "!")
    static let doubleQuote = UInt8(ascii: "\"")
    static let hash = UInt8(ascii: "#")
    static let ampersand = UInt8(ascii: "&")
    static let singleQuote = UInt8(ascii: "'")
    static let openParen = UInt8(ascii: "(")
    static let closeParen = UInt8(ascii: ")")
    static let asterisk = UInt8(ascii: "*")
    static let plus = UInt8(ascii: "+")
    static let dash = UInt8(ascii: "-")
    static let dot = UInt8(ascii: ".")
    static let slash = UInt8(ascii: "/")
    static let colon = UInt8(ascii: ":")
    static let semicolon = UInt8(ascii: ";")
    static let lessThan = UInt8(ascii: "<")
    static let equals = UInt8(ascii: "=")
    static let greaterThan = UInt8(ascii: ">")
    static let question = UInt8(ascii: "?")
    static let at = UInt8(ascii: "@")
    static let openBracket = UInt8(ascii: "[")
    static let backslash = UInt8(ascii: "\\")
    static let closeBracket = UInt8(ascii: "]")
    static let underscore = UInt8(ascii: "_")
    static let backtick = UInt8(ascii: "`")
    static let tilde = UInt8(ascii: "~")

    static func isSpaceOrTab(_ byte: UInt8?) -> Bool { byte == space || byte == tab }

    /// Space, tab, line feed, vertical tab, form feed, carriage return.
    static func isWhitespace(_ byte: UInt8) -> Bool { byte == space || (byte >= 0x09 && byte <= 0x0D) }

    static func isDigit(_ byte: UInt8) -> Bool { byte >= 0x30 && byte <= 0x39 }

    static func isLetter(_ byte: UInt8) -> Bool { (byte | 0x20) >= 0x61 && (byte | 0x20) <= 0x7A }

    static func isAlphanumeric(_ byte: UInt8) -> Bool { isDigit(byte) || isLetter(byte) }

    static func isHexDigit(_ byte: UInt8) -> Bool { isDigit(byte) || ((byte | 0x20) >= 0x61 && (byte | 0x20) <= 0x66) }

    /// ASCII punctuation: the characters a backslash can escape.
    static func isPunctuation(_ byte: UInt8) -> Bool {
        (byte >= 0x21 && byte <= 0x2F) || (byte >= 0x3A && byte <= 0x40) || (byte >= 0x5B && byte <= 0x60) || (byte >= 0x7B && byte <= 0x7E)
    }

    static func lowercased(_ byte: UInt8) -> UInt8 { byte >= 0x41 && byte <= 0x5A ? byte | 0x20 : byte }
}

extension Array where Element == UInt8 {
    /// The byte at `index`, or nil past either end.
    @inline(__always)
    func at(_ index: Int) -> UInt8? { index >= 0 && index < count ? self[index] : nil }

    func string(_ range: Range<Int>) -> String { String(decoding: self[range], as: UTF8.self) }

    var string: String { String(decoding: self, as: UTF8.self) }

    /// Whether the bytes at `index` are `ascii`, ignoring ASCII case.
    func hasPrefix(_ ascii: String, at index: Int, caseInsensitive: Bool = false) -> Bool {
        var position = index
        for expected in ascii.utf8 {
            guard position < count else { return false }
            let actual = caseInsensitive ? Byte.lowercased(self[position]) : self[position]
            if actual != (caseInsensitive ? Byte.lowercased(expected) : expected) { return false }
            position += 1
        }
        return true
    }

    /// True when only spaces and tabs (or nothing) remain from `index`.
    func isBlank(from index: Int) -> Bool {
        var position = index
        while position < count {
            if !Byte.isSpaceOrTab(self[position]) { return false }
            position += 1
        }
        return true
    }
}

/// Unicode classes the delimiter rules are defined on.
public enum UnicodeClass {
    /// Unicode whitespace: Zs, tab, line feed, form feed, carriage return.
    public static func isWhitespace(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x09, 0x0A, 0x0C, 0x0D, 0x20: return true
        case 0..<0x80: return false
        default: return scalar.properties.generalCategory == .spaceSeparator
        }
    }

    /// Unicode punctuation: general categories P and S (CommonMark 0.31).
    public static func isPunctuation(_ scalar: Unicode.Scalar) -> Bool {
        if scalar.value < 0x80 { return Byte.isPunctuation(UInt8(scalar.value)) }
        switch scalar.properties.generalCategory {
        case .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation, .initialPunctuation,
             .finalPunctuation, .otherPunctuation, .mathSymbol, .currencySymbol, .modifierSymbol, .otherSymbol:
            return true
        default:
            return false
        }
    }
}

extension Array where Element == UInt8 {
    /// The scalar starting at `index` (a line feed past the end, as the delimiter rules expect).
    func scalar(at index: Int) -> Unicode.Scalar {
        guard index >= 0, index < count else { return "\n" }
        let lead = self[index]
        if lead < 0x80 { return Unicode.Scalar(lead) }
        let length = lead >= 0xF0 ? 4 : lead >= 0xE0 ? 3 : 2
        guard index + length <= count else { return "\u{FFFD}" }
        return String(decoding: self[index..<(index + length)], as: UTF8.self).unicodeScalars.first ?? "\u{FFFD}"
    }

    /// The scalar ending right before `index` (a line feed before the start).
    func scalar(before index: Int) -> Unicode.Scalar {
        guard index > 0, index <= count else { return "\n" }
        var start = index - 1
        while start > 0, self[start] & 0xC0 == 0x80 { start -= 1 }
        return scalar(at: start)
    }
}

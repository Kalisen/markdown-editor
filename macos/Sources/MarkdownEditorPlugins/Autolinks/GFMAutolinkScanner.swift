/// A bare URL or email address found in text.
public struct AutolinkMatch: Equatable {
    /// Index of the first scalar in the scanned text.
    public let start: Int
    /// Number of scalars of the linked text.
    public let length: Int
    /// The link target (scheme added for www and email links).
    public let url: String
}

/// GFM extended autolinks (spec 0.29, section 6.9): www, http(s)/ftp URLs and email addresses.
public enum GFMAutolinkScanner {
    private static let wwwPrefix = "www."
    private static let defaultScheme = "http://"
    private static let mailtoScheme = "mailto:"
    private static let schemePrefixes = ["http://", "https://", "ftp://"]
    private static let trailingPunctuation = Set("?!.,:*_~".unicodeScalars)
    private static let boundaryCharacters = Set("*_~(".unicodeScalars)
    private static let emailLocalExtras = Set(".-_+".unicodeScalars)

    /// - Parameters:
    ///   - text: plain text to scan.
    ///   - startsAtBoundary: whether the position before the text counts as a boundary (start of line, after emphasis...).
    public static func scan(_ text: String, startsAtBoundary: Bool = true) -> [AutolinkMatch] {
        let scalars = Array(text.unicodeScalars)
        var matches: [AutolinkMatch] = []
        var index = 0
        while index < scalars.count {
            let atBoundary = index == 0
                ? startsAtBoundary
                : scalars[index - 1].properties.isWhitespace || boundaryCharacters.contains(scalars[index - 1])
            if atBoundary, let match = wwwOrURL(scalars, at: index) ?? email(scalars, at: index) {
                matches.append(match)
                index = match.start + match.length
                continue
            }
            index += 1
        }
        return matches
    }

    private static func wwwOrURL(_ text: [Unicode.Scalar], at start: Int) -> AutolinkMatch? {
        var prefix: String?
        if hasPrefix(text, wwwPrefix, at: start) { prefix = "" }
        for scheme in schemePrefixes where hasPrefix(text, scheme, at: start) { prefix = scheme }
        guard let prefix else { return nil }

        let domainStart = start + prefix.unicodeScalars.count
        var domainEnd = domainStart
        while domainEnd < text.count, isASCIILetterOrDigit(text[domainEnd]) || text[domainEnd] == "-" || text[domainEnd] == "_" || text[domainEnd] == "." {
            domainEnd += 1
        }
        guard isValidDomain(string(text, domainStart..<domainEnd)) else { return nil }

        var end = domainEnd
        while end < text.count, !text[end].properties.isWhitespace, text[end] != "<" { end += 1 }
        end = trimTrailing(text, start: start, end: end)
        guard end > domainStart else { return nil }

        let linked = string(text, start..<end)
        return AutolinkMatch(start: start, length: end - start, url: prefix.isEmpty ? defaultScheme + linked : linked)
    }

    /// At least one period; no underscore in the last two segments.
    private static func isValidDomain(_ domain: String) -> Bool {
        var trimmed = Substring(domain)
        while trimmed.hasSuffix(".") { trimmed.removeLast() }
        let segments = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count >= 2, !segments.contains(where: \.isEmpty) else { return false }
        return !segments[segments.count - 1].contains("_") && !segments[segments.count - 2].contains("_")
    }

    /// Extended autolink path validation: trailing punctuation, unbalanced `)` and entity references are excluded.
    private static func trimTrailing(_ text: [Unicode.Scalar], start: Int, end: Int) -> Int {
        var end = end
        while end > start {
            let last = text[end - 1]
            if trailingPunctuation.contains(last) {
                end -= 1
            } else if last == ")", count(text, start..<end, ")") > count(text, start..<end, "(") {
                end -= 1
            } else if last == ";", let entityStart = entityStart(text, start: start, end: end) {
                end = entityStart
            } else {
                break
            }
        }
        return end
    }

    private static func entityStart(_ text: [Unicode.Scalar], start: Int, end: Int) -> Int? {
        var index = end - 2
        while index >= start, isASCIILetterOrDigit(text[index]) { index -= 1 }
        return index >= start && index < end - 2 && text[index] == "&" ? index : nil
    }

    private static func email(_ text: [Unicode.Scalar], at start: Int) -> AutolinkMatch? {
        var at = start
        while at < text.count, isASCIILetterOrDigit(text[at]) || emailLocalExtras.contains(text[at]) { at += 1 }
        guard at > start, at < text.count, text[at] == "@" else { return nil }

        var end = at + 1
        while end < text.count, isASCIILetterOrDigit(text[end]) || text[end] == "-" || text[end] == "_" || text[end] == "." { end += 1 }
        if end > at + 1, text[end - 1] == "." { end -= 1 } // a trailing period is not part of the address
        let domain = text[(at + 1)..<end]
        guard let last = domain.last, domain.contains("."), last != "-", last != "_" else { return nil }
        // The address must not continue with characters that are invalid in it (e.g. "@a.b-" or "@a.b_").
        if end < text.count, text[end] == "-" || text[end] == "_" { return nil }

        let linked = string(text, start..<end)
        return AutolinkMatch(start: start, length: end - start, url: mailtoScheme + linked)
    }

    private static func hasPrefix(_ text: [Unicode.Scalar], _ prefix: String, at start: Int) -> Bool {
        var index = start
        for expected in prefix.unicodeScalars {
            guard index < text.count, text[index].properties.lowercaseMapping == String(expected) else { return false }
            index += 1
        }
        return true
    }

    private static func isASCIILetterOrDigit(_ scalar: Unicode.Scalar) -> Bool {
        scalar.isASCII && (scalar.properties.isAlphabetic || (scalar.value >= 0x30 && scalar.value <= 0x39))
    }

    private static func count(_ text: [Unicode.Scalar], _ range: Range<Int>, _ scalar: Unicode.Scalar) -> Int {
        text[range].reduce(0) { $0 + ($1 == scalar ? 1 : 0) }
    }

    static func string(_ text: [Unicode.Scalar], _ range: Range<Int>) -> String {
        var result = String.UnicodeScalarView()
        result.append(contentsOf: text[range])
        return String(result)
    }
}

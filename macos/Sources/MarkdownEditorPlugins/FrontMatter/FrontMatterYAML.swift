import Foundation

/// A top-level front matter entry: a scalar, a list, or (for nested mappings) raw YAML text.
public struct FrontMatterEntry: Equatable {
    public let key: String
    public let values: [String]
    public let isRaw: Bool

    public init(key: String, values: [String], isRaw: Bool = false) {
        self.key = key
        self.values = values
        self.isRaw = isRaw
    }
}

/// Minimal YAML reader for front matter tables: top-level `key: value` scalars, inline lists `[a, b]` and
/// block lists (`- item`). Nested mappings are kept as raw text.
public enum FrontMatterYAML {
    private static let listItemPrefix = "- "

    public static func parse(_ yaml: String) -> [FrontMatterEntry] {
        var entries: [FrontMatterEntry] = []
        let lines = yaml.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var index = 0
        while index < lines.count {
            defer { index += 1 }
            guard let match = trimmingEnd(lines[index]).wholeMatch(of: #/(?<key>[^\s#:][^:]*?):(?:\s+(?<value>.*))?/#) else { continue }
            let key = unquote(String(match.key).trimmingCharacters(in: .whitespaces))
            let value = stripComment(String(match.value ?? "")).trimmingCharacters(in: .whitespaces)
            if !value.isEmpty {
                entries.append(FrontMatterEntry(key: key, values: isInlineList(value) ? splitInlineList(value) : [unquote(value)]))
                continue
            }

            var nested: [String] = []
            while index + 1 < lines.count,
                  lines[index + 1].isEmpty || lines[index + 1].first!.isWhitespace || lines[index + 1].hasPrefix(listItemPrefix) {
                index += 1
                nested.append(lines[index])
            }
            while let last = nested.last, last.trimmingCharacters(in: .whitespaces).isEmpty { nested.removeLast() }

            let items = nested.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            if !items.isEmpty, items.allSatisfy({ $0.hasPrefix(listItemPrefix) }) {
                let values = items.map { unquote(stripComment(String($0.dropFirst(listItemPrefix.count))).trimmingCharacters(in: .whitespaces)) }
                entries.append(FrontMatterEntry(key: key, values: values))
            } else {
                entries.append(FrontMatterEntry(key: key, values: items.isEmpty ? [] : [dedent(nested)], isRaw: !items.isEmpty))
            }
        }
        return entries
    }

    private static func isInlineList(_ value: String) -> Bool { value.hasPrefix("[") && value.hasSuffix("]") }

    private static func splitInlineList(_ value: String) -> [String] {
        value.dropFirst().dropLast().split(separator: ",", omittingEmptySubsequences: false)
            .map { unquote($0.trimmingCharacters(in: .whitespaces)) }.filter { !$0.isEmpty }
    }

    private static func unquote(_ value: String) -> String {
        guard value.count >= 2, let first = value.first, first == value.last, first == "\"" || first == "'" else { return value }
        return String(value.dropFirst().dropLast())
    }

    /// Removes a trailing `# comment` outside quotes.
    private static func stripComment(_ value: String) -> String {
        var quote: Character?
        var previous: Character?
        for index in value.indices {
            let character = value[index]
            if let open = quote {
                if character == open { quote = nil }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character == "#", previous == nil || previous!.isWhitespace {
                return String(value[..<index])
            }
            previous = character
        }
        return value
    }

    private static func dedent(_ lines: [String]) -> String {
        func indentation(_ line: String) -> Int { line.prefix { $0.isWhitespace }.count }
        let indent = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.map(indentation).min() ?? 0
        return lines.map { $0.count >= indent ? String($0.dropFirst(indent)) : String($0.drop { $0.isWhitespace }) }.joined(separator: "\n")
    }

    private static func trimmingEnd(_ line: String) -> String {
        var line = Substring(line)
        while let last = line.last, last.isWhitespace { line.removeLast() }
        return String(line)
    }
}

public enum ColumnAlignment: Equatable {
    case none
    case left
    case center
    case right

    var htmlValue: String? {
        switch self {
        case .none: return nil
        case .left: return "left"
        case .center: return "center"
        case .right: return "right"
        }
    }
}

/// Line-level rules of GFM tables (spec 0.29, section 4.10).
enum GFMTableSyntax {
    private static let maxIndent = 3

    /// Splits a row into raw cell texts on unescaped pipes; leading/trailing pipes are optional.
    static func splitCells(_ line: String) -> [String] {
        var text = Array(trim(line))
        if text.first == "|" { text.removeFirst() }
        if text.last == "|", !isEscaped(text, at: text.count - 1) { text.removeLast() }

        var cells: [String] = []
        var current = ""
        for index in text.indices {
            if text[index] == "|", !isEscaped(text, at: index) {
                cells.append(trim(current))
                current = ""
            } else {
                current.append(text[index])
            }
        }
        cells.append(trim(current))
        return cells
    }

    /// GFM: `\|` inside a cell becomes a literal pipe before inline parsing (also inside code spans).
    static func unescapePipes(_ cell: String) -> String {
        cell.replacingOccurrences(of: "\\|", with: "|")
    }

    /// - Returns: the column alignments, or nil when the line is not a delimiter row.
    static func parseDelimiterRow(_ line: String) -> [ColumnAlignment]? {
        guard leadingSpaces(line) <= maxIndent else { return nil }
        let trimmed = trim(line)
        guard !trimmed.isEmpty, trimmed.contains("|") || trimmed.contains(":") else { return nil }

        var alignments: [ColumnAlignment] = []
        for cell in splitCells(trimmed) {
            let left = cell.hasPrefix(":")
            let right = cell.hasSuffix(":") && cell.count > 1
            let dashes = cell.dropFirst(left ? 1 : 0).dropLast(right ? 1 : 0)
            guard !dashes.isEmpty, dashes.allSatisfy({ $0 == "-" }) else { return nil }
            switch (left, right) {
            case (true, true): alignments.append(.center)
            case (true, false): alignments.append(.left)
            case (false, true): alignments.append(.right)
            case (false, false): alignments.append(.none)
            }
        }
        return alignments
    }

    /// GFM: the table ends at the first blank line or at the beginning of another block-level structure.
    static func startsOtherBlock(_ line: String) -> Bool {
        guard leadingSpaces(line) <= maxIndent else { return false } // indented code cannot interrupt
        let text = Array(line.drop { $0 == " " || $0 == "\t" })
        guard let first = text.first else { return true }
        switch first {
        case ">", "#", "<": return true
        case "`": return text.starts(with: Array("```"))
        case "~": return text.starts(with: Array("~~~"))
        case "*", "-", "+": return text.count == 1 || text[1] == " " || isThematicBreak(text)
        case "_": return isThematicBreak(text)
        default: return isOrderedListStart(text)
        }
    }

    private static func isThematicBreak(_ text: [Character]) -> Bool {
        let compact = text.filter { $0 != " " && $0 != "\t" }
        guard compact.count >= 3, let marker = compact.first, marker == "*" || marker == "-" || marker == "_" else { return false }
        return compact.allSatisfy { $0 == marker }
    }

    private static func isOrderedListStart(_ text: [Character]) -> Bool {
        var digits = 0
        while digits < text.count, digits < 10, text[digits].isASCII, text[digits].isNumber { digits += 1 }
        guard digits > 0, digits < 10, digits < text.count, text[digits] == "." || text[digits] == ")" else { return false }
        return digits + 1 == text.count || text[digits + 1] == " "
    }

    private static func leadingSpaces(_ line: String) -> Int {
        var count = 0
        for character in line {
            if character == " " { count += 1 } else if character == "\t" { count += 4 } else { break }
        }
        return count
    }

    private static func isEscaped(_ text: [Character], at index: Int) -> Bool {
        var backslashes = 0
        var position = index - 1
        while position >= 0, text[position] == "\\" {
            backslashes += 1
            position -= 1
        }
        return backslashes % 2 == 1
    }

    private static func trim(_ text: String) -> String {
        var result = Substring(text)
        while let first = result.first, first.isWhitespace { result.removeFirst() }
        while let last = result.last, last.isWhitespace { result.removeLast() }
        return String(result)
    }
}

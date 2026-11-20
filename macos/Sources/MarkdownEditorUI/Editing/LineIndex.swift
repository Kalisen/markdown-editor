import Foundation

/// Where each source line starts in the editor's text (UTF-16 offsets). Lines end at `\n`, `\r\n` or `\r`,
/// as the Markdown engine counts them, so line numbers agree with the preview's `data-line` attributes.
struct LineIndex {
    private(set) var lineStarts: [Int] = [0]

    init(_ text: NSString = "") {
        let length = text.length
        guard length > 0 else { return }
        var buffer = [unichar](repeating: 0, count: length)
        text.getCharacters(&buffer, range: NSRange(location: 0, length: length))
        var index = 0
        while index < length {
            let character = buffer[index]
            if character == 0x0D {
                if index + 1 < length, buffer[index + 1] == 0x0A { index += 1 }
                lineStarts.append(index + 1)
            } else if character == 0x0A {
                lineStarts.append(index + 1)
            }
            index += 1
        }
    }

    var lineCount: Int { lineStarts.count }

    /// The 0-based line containing the UTF-16 offset.
    func line(at offset: Int) -> Int {
        var low = 0
        var high = lineStarts.count
        while low < high {
            let middle = (low + high) / 2
            if lineStarts[middle] <= offset { low = middle + 1 } else { high = middle }
        }
        return max(0, low - 1)
    }

    func start(ofLine line: Int) -> Int {
        lineStarts[min(max(line, 0), lineStarts.count - 1)]
    }

    /// The characters of the line, including its line ending.
    func range(ofLine line: Int, textLength: Int) -> NSRange {
        let start = start(ofLine: line)
        let end = line + 1 < lineStarts.count ? lineStarts[line + 1] : textLength
        return NSRange(location: start, length: max(0, end - start))
    }
}

import CommonMark
import MarkdownEditorCore

/// GitHub emoji shortcodes (`:smile:`, `:+1:`…) render as Unicode emoji. Text smileys such as `:)` are
/// left alone, as on GitHub.
public struct EmojiPlugin: MarkdownPlugin, DocumentFeatureProbe {
    public static let pluginID = "emoji"

    public init() {}

    public var id: String { Self.pluginID }
    public var name: String { "Emoji shortcodes" }
    public var version: PluginVersion { PluginVersion(1, 0, 0) }
    public var previewAssets: [PreviewAsset] { [] }

    public func isUsed(by document: Document) -> Bool {
        document.hasDescendant(ofType: Emoji.self)
    }

    public func configurePipeline(_ builder: MarkdownPipelineBuilder) {
        builder.addInlineStart(InlineStart(triggerCharacters: [UInt8(ascii: ":")], tryParse: Self.parseShortcode))
    }

    /// A shortcode is not recognized right after a letter or a digit (e.g. the time `10:30:00`).
    private static func parseShortcode(_ parser: InlineParser) -> Bool {
        let before = parser.scalarBefore
        guard !before.properties.isAlphabetic, before.properties.numericType == nil else { return false }
        var end = parser.position + 1
        while let byte = parser.peek(end - parser.position), EmojiShortcodes.isNameByte(byte), end - parser.position <= EmojiShortcodes.maxNameLength {
            end += 1
        }
        guard end > parser.position + 1, parser.peek(end - parser.position) == UInt8(ascii: ":"),
              let emoji = EmojiShortcodes.emoji(named: parser.text((parser.position + 1)..<end)) else { return false }
        parser.append(Emoji(emoji))
        parser.position = end + 1
        return true
    }
}

/// An emoji written as a shortcode.
final class Emoji: Text {}

enum EmojiShortcodes {
    static let maxNameLength = 40

    private static let emojiByName: [String: String] = {
        var result: [String: String] = [:]
        result.reserveCapacity(1700)
        for line in table.split(separator: "\n") {
            guard let space = line.firstIndex(of: " ") else { continue }
            result[String(line[..<space])] = String(line[line.index(after: space)...])
        }
        return result
    }()

    /// - Parameter name: the shortcode without its colons.
    static func emoji(named name: String) -> String? { emojiByName[name] }

    /// Lowercase letters, digits, `_`, `+` and `-`.
    static func isNameByte(_ byte: UInt8) -> Bool {
        (byte >= 0x61 && byte <= 0x7A) || (byte >= 0x30 && byte <= 0x39) || byte == 0x5F || byte == 0x2B || byte == 0x2D
    }
}

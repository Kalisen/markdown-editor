import Foundation

public enum PreviewInboundMessage: Equatable {
    case ready
    case openLink(href: String)
    /// Where user input scrolled the preview.
    case scrolled(ScrollPosition)
}

/// Messages exchanged with the preview page (see shared/preview/preview.js). Rendered HTML is posted as a
/// plain string message; these JSON messages carry control information.
public enum PreviewMessages {
    /// Host to page: the editor drives; follow its `ScrollPosition`.
    public static let scrollToLineType = "scroll-to-line"
    public static let readyType = "ready"
    public static let openLinkType = "open-link"
    /// Page to host: the preview drives; it reports its `ScrollPosition`.
    public static let scrolledType = "scrolled"

    private static let typeProperty = "type"
    private static let hrefProperty = "href"
    private static let lineProperty = "line"
    private static let tailProperty = "tail"

    public static func scrollToLine(_ position: ScrollPosition) -> String {
        let message: [String: Any] = [
            typeProperty: scrollToLineType,
            lineProperty: max(0, position.line),
            tailProperty: min(1, max(0, position.tail)),
        ]
        // The values are a string and finite numbers: serialization cannot fail.
        return String(decoding: try! JSONSerialization.data(withJSONObject: message, options: [.sortedKeys]), as: UTF8.self)
    }

    /// Parses a message posted by the preview page. Anything malformed or unknown yields nil:
    /// page content is untrusted and must never be able to crash the host.
    public static func parse(_ json: String?) -> PreviewInboundMessage? {
        guard let json, !json.isEmpty,
              let root = try? JSONSerialization.jsonObject(with: Data(json.utf8), options: [.fragmentsAllowed]) as? [String: Any],
              let type = root[typeProperty] as? String else { return nil }
        switch type {
        case readyType:
            return .ready
        case openLinkType:
            return (root[hrefProperty] as? String).map { .openLink(href: $0) }
        case scrolledType:
            guard let line = number(root[lineProperty]) else { return nil }
            return .scrolled(ScrollPosition(line: line, tail: min(1, number(root[tailProperty]) ?? 0)))
        default:
            return nil
        }
    }

    /// A finite, non-negative number, or nil.
    private static func number(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let double = number.doubleValue
        return double.isFinite && double >= 0 ? double : nil
    }
}

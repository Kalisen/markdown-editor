import CommonMark

/// GitHub-compatible heading ids: lowercase, spaces to hyphens, punctuation removed, duplicates suffixed
/// `-1`, `-2`… Shared by the heading anchors and the table of contents, so both agree on the ids.
enum HeadingIdentifiers {
    static let emptyHeadingID = "section"
    private static let processorKey = "heading-identifiers"

    static func register(in builder: MarkdownPipelineBuilder) {
        builder.addDocumentProcessor(key: processorKey, assign)
    }

    static func assign(in document: Document) {
        var used = Set<String>()
        for heading in document.descendants(ofType: Heading.self) where heading.attributes.id == nil {
            let base = slug(text(of: heading, lineBreak: ""))
            var id = base
            var suffix = 0
            while !used.insert(id).inserted {
                suffix += 1
                id = "\(base)-\(suffix)"
            }
            heading.attributes.id = id
        }
    }

    /// The heading's literal text and code spans; other inline content (math, footnote references) is left out.
    static func text(of heading: Heading, lineBreak: String) -> String {
        var text = ""
        for node in heading.descendants {
            switch node {
            case let literal as Text: text += literal.literal
            case let code as Code: text += code.literal
            case is SoftBreak, is LineBreak: text += lineBreak
            default: break
            }
        }
        return text
    }

    static func slug(_ text: String) -> String {
        var slug = ""
        for character in text {
            if character.isLetter || character.isNumber {
                slug += character.lowercased()
            } else if character == " " {
                slug += "-"
            } else if character == "-" || character == "_" {
                slug.append(character)
            }
        }
        return slug.isEmpty ? emptyHeadingID : slug
    }
}

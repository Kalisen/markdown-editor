/// Inline content of a leaf block.
open class Inline: Node {}

public final class SoftBreak: Inline {
    public override func writeHTML(to renderer: HTMLRenderer) { renderer.write("\n") }

    public override var plainText: String { " " }
}

public final class LineBreak: Inline {
    public override func writeHTML(to renderer: HTMLRenderer) {
        if renderer.isWritingPlainText {
            renderer.write("\n")
        } else {
            renderer.write("<br />\n")
        }
    }

    public override var plainText: String { " " }
}

/// Literal text.
open class Text: Inline {
    public var literal: String

    public init(_ literal: String) {
        self.literal = literal
    }

    open override func writeHTML(to renderer: HTMLRenderer) { renderer.writeEscaped(literal) }

    open override var plainText: String { literal }
}

/// A code span.
public final class Code: Inline {
    public var literal: String

    public init(_ literal: String) {
        self.literal = literal
    }

    public override func writeHTML(to renderer: HTMLRenderer) {
        if renderer.isWritingPlainText {
            renderer.writeEscaped(literal)
        } else {
            renderer.write("<code")
            renderer.writeAttributes(of: self)
            renderer.write(">")
            renderer.writeEscaped(literal)
            renderer.write("</code>")
        }
    }

    public override var plainText: String { literal }
}

/// Raw inline HTML.
public final class HTMLInline: Inline {
    public var literal: String

    public init(_ literal: String) {
        self.literal = literal
    }

    public override func writeHTML(to renderer: HTMLRenderer) { renderer.write(literal) }

    public override var plainText: String { "" }
}

/// Emphasis made of a delimiter run: `*`/`_` (one delimiter: emphasis, two: strong) or a registered extra delimiter.
public final class Emphasis: Inline {
    public let delimiter: UInt8
    public let delimiterCount: Int
    public let tagName: String

    public init(delimiter: UInt8, delimiterCount: Int, tagName: String) {
        self.delimiter = delimiter
        self.delimiterCount = delimiterCount
        self.tagName = tagName
    }

    public override func writeHTML(to renderer: HTMLRenderer) {
        if renderer.isWritingPlainText {
            renderer.renderChildren(of: self)
            return
        }
        renderer.write("<\(tagName)")
        renderer.writeAttributes(of: self)
        renderer.write(">")
        renderer.renderChildren(of: self)
        renderer.write("</\(tagName)>")
    }
}

public final class Link: Inline {
    /// The target as written (unescaped); it is percent-encoded when rendered.
    public var destination: String
    public var title: String?

    public init(destination: String, title: String? = nil) {
        self.destination = destination
        self.title = title
    }

    public override func writeHTML(to renderer: HTMLRenderer) {
        if renderer.isWritingPlainText {
            renderer.renderChildren(of: self)
            return
        }
        renderer.write("<a href=\"")
        renderer.writeEscaped(LinkDestination.normalize(destination))
        renderer.write("\"")
        renderer.writeAttributes(of: self)
        if let title, !title.isEmpty {
            renderer.write(" title=\"")
            renderer.writeEscaped(title)
            renderer.write("\"")
        }
        renderer.write(">")
        renderer.renderChildren(of: self)
        renderer.write("</a>")
    }
}

public final class Image: Inline {
    /// The source as written (unescaped); it is percent-encoded when rendered.
    public var destination: String
    public var title: String?

    public init(destination: String, title: String? = nil) {
        self.destination = destination
        self.title = title
    }

    public override func writeHTML(to renderer: HTMLRenderer) {
        if renderer.isWritingPlainText {
            renderer.renderChildren(of: self)
            return
        }
        renderer.write("<img src=\"")
        renderer.writeEscaped(LinkDestination.normalize(destination))
        renderer.write("\"")
        renderer.writeAttributes(of: self)
        renderer.write(" alt=\"")
        renderer.writePlainText { renderer.renderChildren(of: self) }
        renderer.write("\"")
        if let title, !title.isEmpty {
            renderer.write(" title=\"")
            renderer.writeEscaped(title)
            renderer.write("\"")
        }
        renderer.write(" />")
    }
}

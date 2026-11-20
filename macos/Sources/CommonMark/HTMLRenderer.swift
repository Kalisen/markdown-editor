/// Writes a document tree as HTML. Each node writes itself (`Node.writeHTML`); a pipeline may wrap the
/// rendering of a node type (`MarkdownPipelineBuilder.wrapRendering`).
public final class HTMLRenderer {
    public typealias Wrapper = (_ node: Node, _ renderer: HTMLRenderer, _ original: () -> Void) -> Void

    private var output: [UInt8] = []
    private var plainTextDepth = 0
    private let wrappers: [ObjectIdentifier: [Wrapper]]

    init(wrappers: [ObjectIdentifier: [Wrapper]], capacity: Int) {
        self.wrappers = wrappers
        output.reserveCapacity(capacity)
    }

    var html: String { output.string }

    /// True while writing an image description: only text is written, no tags.
    public var isWritingPlainText: Bool { plainTextDepth > 0 }

    public func render(_ node: Node) {
        guard let chain = wrappers[ObjectIdentifier(type(of: node))] else {
            node.writeHTML(to: self)
            return
        }
        render(node, through: chain[...])
    }

    private func render(_ node: Node, through chain: ArraySlice<Wrapper>) {
        guard let outermost = chain.last else {
            node.writeHTML(to: self)
            return
        }
        outermost(node, self) { self.render(node, through: chain.dropLast()) }
    }

    public func renderChildren(of node: Node) {
        var child = node.firstChild
        while let current = child {
            render(current)
            child = current.next
        }
    }

    /// Writes text as is.
    public func write(_ html: String) {
        output.append(contentsOf: html.utf8)
    }

    /// Writes text with `&`, `<`, `>` and `"` escaped.
    public func writeEscaped(_ text: String) {
        for byte in text.utf8 {
            switch byte {
            case Byte.ampersand: output.append(contentsOf: "&amp;".utf8)
            case Byte.lessThan: output.append(contentsOf: "&lt;".utf8)
            case Byte.greaterThan: output.append(contentsOf: "&gt;".utf8)
            case Byte.doubleQuote: output.append(contentsOf: "&quot;".utf8)
            default: output.append(byte)
            }
        }
    }

    /// Starts a new line unless the output is already at the start of one.
    public func ensureLine() {
        if let last = output.last, last != Byte.newline { output.append(Byte.newline) }
    }

    /// Writes the node's attributes, each preceded by a space: id, class, then properties.
    public func writeAttributes(of node: Node) {
        let attributes = node.attributes
        guard !attributes.isEmpty else { return }
        if let id = attributes.id {
            write(" id=\"")
            writeEscaped(id)
            write("\"")
        }
        if !attributes.classes.isEmpty {
            write(" class=\"")
            writeEscaped(attributes.classes.joined(separator: " "))
            write("\"")
        }
        for property in attributes.properties {
            write(" \(property.name)=\"")
            writeEscaped(property.value)
            write("\"")
        }
    }

    /// Runs `body` with tags suppressed, for attribute values such as an image description.
    public func writePlainText(_ body: () -> Void) {
        plainTextDepth += 1
        body()
        plainTextDepth -= 1
    }
}

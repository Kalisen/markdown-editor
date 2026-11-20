/// HTML attributes attached to a node, written in the order id, class, properties.
public struct HTMLAttributes {
    public var id: String?
    public private(set) var classes: [String] = []
    public private(set) var properties: [(name: String, value: String)] = []

    public init() {}

    public var isEmpty: Bool { id == nil && classes.isEmpty && properties.isEmpty }

    public mutating func addClass(_ name: String) {
        if !classes.contains(name) { classes.append(name) }
    }

    public mutating func addProperty(_ name: String, _ value: String) {
        properties.append((name, value))
    }

    /// Adds the property unless one with the same name exists.
    public mutating func addPropertyIfAbsent(_ name: String, _ value: String) {
        if !properties.contains(where: { $0.name == name }) { properties.append((name, value)) }
    }

    public func property(_ name: String) -> String? {
        properties.first { $0.name == name }?.value
    }
}

/// A node of the document tree. Children are a doubly linked list, so parsers and document processors
/// can splice nodes in constant time.
open class Node {
    public private(set) unowned(unsafe) var parent: Node?
    public private(set) var firstChild: Node?
    public private(set) unowned(unsafe) var lastChild: Node?
    public private(set) var next: Node?
    public private(set) unowned(unsafe) var previous: Node?

    public var attributes = HTMLAttributes()

    public init() {}

    deinit {
        // Released iteratively: a long sibling chain or a deep tree must not recurse through deinit.
        var pending: [Node] = []
        if let child = firstChild { pending.append(child); firstChild = nil }
        if let sibling = next { pending.append(sibling); next = nil }
        while var node = pending.popLast() {
            node.previous = nil
            guard isKnownUniquelyReferenced(&node) else {
                // Still referenced from outside the tree: it survives with its siblings, now without a parent.
                var orphan: Node? = node
                while let current = orphan {
                    current.parent = nil
                    orphan = current.next
                }
                continue
            }
            if let child = node.firstChild { pending.append(child); node.firstChild = nil }
            if let sibling = node.next { pending.append(sibling); node.next = nil }
        }
    }

    // MARK: Tree editing

    public func appendChild(_ child: Node) {
        child.unlink()
        child.parent = self
        if let last = lastChild {
            last.next = child
            child.previous = last
        } else {
            firstChild = child
        }
        lastChild = child
    }

    public func prependChild(_ child: Node) {
        if let first = firstChild { first.insertBefore(child) } else { appendChild(child) }
    }

    /// Inserts `sibling` right after this node.
    public func insertAfter(_ sibling: Node) {
        guard let parent else { return }
        sibling.unlink()
        sibling.parent = parent
        sibling.previous = self
        sibling.next = next
        if let next { next.previous = sibling } else { parent.lastChild = sibling }
        next = sibling
    }

    /// Inserts `sibling` right before this node.
    public func insertBefore(_ sibling: Node) {
        guard let parent else { return }
        sibling.unlink()
        sibling.parent = parent
        sibling.next = self
        sibling.previous = previous
        if let previous { previous.next = sibling } else { parent.firstChild = sibling }
        previous = sibling
    }

    /// Removes this node (with its subtree) from its parent.
    public func unlink() {
        guard let parent else { return }
        let following = next
        if let previous { previous.next = following } else { parent.firstChild = following }
        if let following { following.previous = previous } else { parent.lastChild = previous }
        self.parent = nil
        next = nil
        previous = nil
    }

    /// Puts `replacement` where this node is, and removes this node.
    public func replace(with replacement: Node) {
        insertAfter(replacement)
        unlink()
    }

    /// Moves every child of this node to the end of `target`.
    public func moveChildren(to target: Node) {
        while let child = firstChild { target.appendChild(child) }
    }

    // MARK: Traversal

    public var children: [Node] {
        var result: [Node] = []
        var child = firstChild
        while let node = child {
            result.append(node)
            child = node.next
        }
        return result
    }

    /// Every node below this one, in document order.
    public var descendants: [Node] {
        var result: [Node] = []
        var stack: [Node] = []
        if let last = lastChild { stack.append(contentsOf: Self.reversedSiblings(endingAt: last)) }
        while let node = stack.popLast() {
            result.append(node)
            if let last = node.lastChild { stack.append(contentsOf: Self.reversedSiblings(endingAt: last)) }
        }
        return result
    }

    public func descendants<T: Node>(ofType type: T.Type) -> [T] {
        descendants.compactMap { $0 as? T }
    }

    public func firstDescendant<T: Node>(ofType type: T.Type, where predicate: (T) -> Bool = { _ in true }) -> T? {
        for node in descendants { if let match = node as? T, predicate(match) { return match } }
        return nil
    }

    public func hasDescendant<T: Node>(ofType type: T.Type, where predicate: (T) -> Bool = { _ in true }) -> Bool {
        firstDescendant(ofType: type, where: predicate) != nil
    }

    /// The top of the tree this node belongs to.
    public var root: Node {
        var node = self
        while let parent = node.parent { node = parent }
        return node
    }

    private static func reversedSiblings(endingAt last: Node) -> [Node] {
        var result: [Node] = []
        var node: Node? = last
        while let current = node {
            result.append(current)
            node = current.previous
        }
        return result
    }

    // MARK: Rendering

    /// Writes this node as HTML. Subclasses override; the base node only renders its children.
    open func writeHTML(to renderer: HTMLRenderer) {
        renderer.renderChildren(of: self)
    }

    /// Text contribution of this node to a plain-text rendition (image `alt`, heading labels).
    open var plainText: String {
        var text = ""
        var child = firstChild
        while let node = child {
            text += node.plainText
            child = node.next
        }
        return text
    }
}

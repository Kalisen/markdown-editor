import AppKit

/// The bar under the editor: extensions used by the document on the left, then the last action and the
/// number of plugins on the right.
final class StatusBarView: NSView {
    static let height: CGFloat = 24

    private let extensionsLabel = StatusBarView.makeLabel()
    private let statusLabel = StatusBarView.makeLabel()
    private let pluginsLabel = StatusBarView.makeLabel()

    init() {
        super.init(frame: .zero)
        extensionsLabel.lineBreakMode = .byTruncatingTail
        extensionsLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        extensionsLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        for label in [statusLabel, pluginsLabel] {
            label.setContentCompressionResistancePriority(.required, for: .horizontal)
            label.setContentHuggingPriority(.required, for: .horizontal)
        }
        let separator = NSBox()
        separator.boxType = .separator

        let stack = NSStackView(views: [extensionsLabel, statusLabel, pluginsLabel])
        stack.orientation = .horizontal
        stack.distribution = .fill
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        for view in [stack, separator] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.height),
            separator.topAnchor.constraint(equalTo: topAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("StatusBarView is created in code")
    }

    private static func makeLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = .secondaryLabelColor
        return label
    }

    var extensionsText: String { extensionsLabel.stringValue }
    var extensionsDetails: String? { extensionsLabel.toolTip }
    var statusText: String { statusLabel.stringValue }
    var pluginsText: String { pluginsLabel.stringValue }

    /// The extensions used by the document; the tooltip lists every loaded plugin.
    func showExtensions(_ text: String, details: String) {
        extensionsLabel.stringValue = text
        extensionsLabel.toolTip = details
    }

    func showStatus(_ text: String) {
        statusLabel.stringValue = text
    }

    func showPlugins(_ text: String) {
        pluginsLabel.stringValue = text
    }
}

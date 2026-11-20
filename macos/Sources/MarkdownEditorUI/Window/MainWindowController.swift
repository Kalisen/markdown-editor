import AppKit
import MarkdownEditorCore

/// The editor window: Markdown source on the left, live preview on the right, status bar below.
@MainActor
final class MainWindowController: NSWindowController, NSWindowDelegate, NSMenuItemValidation {
    static let appTitle = "Markdown Editor"
    private static let renderDebounce: TimeInterval = 0.3
    /// Lets a burst of file events (one save usually raises several) settle into a single check.
    private static let externalChangeDebounce: TimeInterval = 0.25
    private static let initialSize = NSSize(width: 1300, height: 800)
    private static let logger = Diagnostics.logger(category: "Window")

    private let session: EditorSession
    private let prompts: UserPrompts
    private let renderer: BackgroundRenderer<RenderResult>
    private let plugins: [LoadedPlugin]
    private let failures: [PluginLoadFailure]
    let preview: PreviewHost
    let textView = MarkdownTextView.make()
    let editorScrollView = NSScrollView()
    private let splitView = NSSplitView()
    let statusBar = StatusBarView()
    private let ruler: LineNumberRulerView
    private var scrollSync: ScrollSynchronizer?
    private var renderTimer: Timer?
    private var externalChangeTimer: Timer?
    private var appearanceObservation: NSKeyValueObservation?
    private var isLoadingDocument = false
    private var closeConfirmed = false

    /// The file shown in the editor, to keep the selection and scroll position when it is reloaded.
    private var loadedFile: URL?

    /// True when the editor holds edits not yet copied into the document model. The full text is only
    /// copied when rendering or before a document operation, not on every keystroke.
    private var editorAhead = false

    init(session: EditorSession, prompts: UserPrompts, renderer: MarkdownRenderer, plugins: [LoadedPlugin],
         failures: [PluginLoadFailure], previewFolder: URL) {
        self.session = session
        self.prompts = prompts
        self.plugins = plugins
        self.failures = failures
        self.renderer = BackgroundRenderer { renderer.renderDocument($0, annotateSourceLines: true) }
        preview = PreviewHost(plugins: plugins, previewFolder: previewFolder, theme: SystemTheme.current)
        ruler = LineNumberRulerView(textView: textView, scrollView: editorScrollView)

        let window = NSWindow(contentRect: NSRect(origin: .zero, size: Self.initialSize),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        super.init(window: window)
        window.delegate = self
        window.minSize = NSSize(width: 600, height: 300)
        buildContent(of: window)
        window.center()
        window.setFrameAutosaveName("MainWindow")
        connect()
        loadDocument()
        statusBar.showPlugins(failures.isEmpty
            ? "\(plugins.count) plugin(s) loaded"
            : "\(plugins.count) plugin(s) loaded, \(failures.count) failed (Help > Plugins)")
        preview.load()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("MainWindowController is created in code")
    }

    // MARK: Layout

    private func buildContent(of window: NSWindow) {
        editorScrollView.documentView = textView
        editorScrollView.hasVerticalScroller = true
        editorScrollView.hasHorizontalScroller = false
        editorScrollView.drawsBackground = true
        editorScrollView.backgroundColor = .textBackgroundColor
        editorScrollView.verticalRulerView = ruler
        editorScrollView.hasVerticalRuler = true
        editorScrollView.rulersVisible = true
        editorScrollView.contentView.postsBoundsChangedNotifications = true

        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.addArrangedSubview(editorScrollView)
        splitView.addArrangedSubview(preview.webView)

        let content = NSView()
        for view in [splitView, statusBar] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        NSLayoutConstraint.activate([
            splitView.topAnchor.constraint(equalTo: content.topAnchor),
            splitView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: statusBar.topAnchor),
            statusBar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        window.contentView = content
        window.initialFirstResponder = textView
        // The editor and the preview start with the same width, and keep their proportions when resized.
        window.layoutIfNeeded()
        splitView.setPosition(splitView.bounds.width / 2, ofDividerAt: 0)
    }

    private func connect() {
        let scrollSync = ScrollSynchronizer(
            scrollPreview: { [preview] in preview.scroll(to: $0) },
            scrollEditor: { [weak self] in self?.scrollEditor(to: $0) })
        self.scrollSync = scrollSync

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(editorTextChanged), name: NSText.didChangeNotification, object: textView)
        center.addObserver(self, selector: #selector(editorScrolled), name: NSView.boundsDidChangeNotification, object: editorScrollView.contentView)
        // Includes dragging the scroll bar.
        center.addObserver(self, selector: #selector(editorReceivedInput), name: NSScrollView.willStartLiveScrollNotification, object: editorScrollView)
        textView.onUserInput = { scrollSync.editorReceivedInput() }
        textView.onFilesDropped = { [weak self] in self?.open($0.first) }
        preview.webView.onFilesDropped = { [weak self] in self?.open($0.first) }

        preview.onReady = { [weak self] in self?.renderNow() }
        preview.onScrolled = { scrollSync.previewScrolled(to: $0) }
        preview.onOpenDocumentRequested = { [weak self] in self?.open($0) }
        session.onDocumentChanged = { [weak self] in self?.loadDocument() }

        // The prompt waits until the window is in use: file events only trigger a check while it is the key
        // window, and becoming key always checks (which also covers changes the file watcher missed).
        session.onExternalChangeSuspected = { [weak self] in
            DispatchQueue.main.async { self?.scheduleExternalChangeCheck() }
        }
        appearanceObservation = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            DispatchQueue.main.async { self?.preview.setTheme(SystemTheme.current) }
        }
    }

    // MARK: Document

    private func loadDocument() {
        let document = session.document
        let reloaded = document.fileURL != nil && document.fileURL == loadedFile
        loadedFile = document.fileURL
        isLoadingDocument = true
        if textView.string != document.text {
            let selection = textView.selectedRange()
            let offset = editorScrollView.contentView.bounds.origin
            textView.load(document.text)
            if reloaded {
                textView.setSelectedRange(NSRange(location: min(selection.location, textView.string.utf16.count), length: 0))
                textView.layoutManager?.ensureLayout(for: textView.textContainer!)
                textView.scroll(offset)
            } else {
                textView.setSelectedRange(NSRange(location: 0, length: 0))
                textView.scroll(.zero)
            }
            ruler.updateThickness()
            ruler.needsDisplay = true
        }
        isLoadingDocument = false
        editorAhead = false
        preview.setDocumentFolder(document.folder)
        if let file = document.fileURL { NSDocumentController.shared.noteNewRecentDocumentURL(file) }
        updateTitle()
        renderNow()
    }

    @objc private func editorTextChanged() {
        guard !isLoadingDocument else { return }
        ruler.updateThickness()
        ruler.needsDisplay = true
        if !editorAhead {
            editorAhead = true
            updateTitle()
        }
        renderTimer?.invalidate()
        renderTimer = Timer.scheduledTimer(withTimeInterval: Self.renderDebounce, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.renderNow() }
        }
    }

    private func syncText() {
        guard editorAhead else { return }
        session.document.text = textView.string
        editorAhead = false
    }

    private func renderNow() {
        renderTimer?.invalidate()
        renderTimer = nil
        syncText()
        updateTitle()
        let markdown = session.document.text
        Task { [weak self, renderer] in
            guard let result = await renderer.render(markdown), let self else { return }
            self.preview.render(result.html)
            self.showUsedExtensions(result.usedPlugins)
        }
    }

    /// Runs a document operation on up-to-date text, then refreshes the title.
    @discardableResult
    private func runSession(_ operation: () -> Bool) -> Bool {
        syncText()
        let done = operation()
        updateTitle()
        return done
    }

    /// Opens a file in the editor (after confirmation if the current document has unsaved changes).
    func open(_ file: URL?) {
        guard let file else { return }
        runSession { session.open(file) }
    }

    /// Status bar: the extensions applying to the current document; the tooltip lists all loaded plugins.
    private func showUsedExtensions(_ used: [MarkdownPlugin]) {
        statusBar.showExtensions(PluginUsageText.describe(used), details: PluginUsageText.details(loaded: plugins.map(\.plugin), used: used))
    }

    private func updateTitle() {
        let document = session.document
        window?.title = document.displayName
        window?.representedURL = document.fileURL
        window?.isDocumentEdited = editorAhead || document.isDirty
    }

    // MARK: External changes

    private func scheduleExternalChangeCheck() {
        externalChangeTimer?.invalidate()
        externalChangeTimer = Timer.scheduledTimer(withTimeInterval: Self.externalChangeDebounce, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.window?.isKeyWindow == true else { return }
                self.checkForExternalChange()
            }
        }
    }

    private func checkForExternalChange() {
        if runSession({ session.checkForExternalChange() }) { showReloaded() }
    }

    private func showReloaded() {
        statusBar.showStatus("Reloaded \(session.document.displayName)")
    }

    func windowDidBecomeKey(_ notification: Notification) {
        checkForExternalChange()
    }

    // MARK: Scrolling

    private var editorGeometry: EditorLineGeometry {
        EditorLineGeometry(textView: textView, scrollView: editorScrollView, lineIndex: textView.lineIndex)
    }

    @objc private func editorScrolled() {
        textView.scheduleHighlight()
        ruler.needsDisplay = true
        scrollSync?.editorScrolled(to: editorGeometry.position)
    }

    @objc private func editorReceivedInput() {
        scrollSync?.editorReceivedInput()
    }

    private func scrollEditor(to position: ScrollPosition) {
        textView.scroll(NSPoint(x: 0, y: editorGeometry.offset(for: position)))
    }

    // MARK: Menu actions

    @objc func newFile(_ sender: Any?) {
        runSession { session.new() }
    }

    @objc func openFile(_ sender: Any?) {
        runSession { session.open() }
    }

    @objc func saveFile(_ sender: Any?) {
        runSession { session.save() }
    }

    @objc func saveFileAs(_ sender: Any?) {
        runSession { session.saveAs() }
    }

    @objc func reloadFile(_ sender: Any?) {
        if runSession({ session.reload() }) { showReloaded() }
    }

    @objc func exportToHTML(_ sender: Any?) {
        export(.html)
    }

    @objc func exportToPDF(_ sender: Any?) {
        export(.pdf)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        menuItem.action == #selector(reloadFile(_:)) ? session.document.fileURL != nil : true
    }

    private func export(_ format: ExportFormat) {
        let name = (session.document.displayName as NSString).deletingPathExtension
        guard let file = prompts.askExportFile(suggestedName: "\(name).\(format.fileExtension)", format: format) else { return }
        renderNow() // export what the editor currently shows
        Task { [weak self] in
            guard let self else { return }
            switch format {
            case .pdf: self.finishExport(await self.preview.exportPDF(to: file), file: file)
            case .html: self.finishExport(await self.exportHTML(to: file, title: name), file: file)
            }
        }
    }

    private func finishExport(_ outcome: PreviewHost.PDFExportOutcome, file: URL) {
        switch outcome {
        case .exported: statusBar.showStatus("Exported to \(file.path)")
        case .previewNotReady: prompts.showError("The preview is not ready yet; try exporting again in a moment.")
        case .failed: prompts.showError("Could not export to '\(file.path)'.")
        }
    }

    private func exportHTML(to file: URL, title: String) async -> PreviewHost.PDFExportOutcome {
        guard let snapshot = await preview.snapshot() else { return .previewNotReady }
        let html = HTMLExportBuilder.build(title: title, snapshot: snapshot, theme: preview.theme) { [preview] url in
            guard let stylesheet = preview.stylesheetFile(url) else { return nil }
            do {
                return try String(contentsOf: stylesheet, encoding: .utf8)
            } catch {
                // The export is still written, without this stylesheet.
                Self.logger.warning("Stylesheet left out of the export \(stylesheet.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }
        do {
            try Data(html.utf8).write(to: file, options: .atomic)
            return .exported
        } catch {
            Self.logger.error("Could not export to \(file.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return .failed
        }
    }

    @objc func showPlugins(_ sender: Any?) {
        var lines = plugins.map { "\($0.plugin.name) (\($0.plugin.id)) v\($0.plugin.version)" }
        if plugins.isEmpty { lines.append("No plugins loaded.") }
        if !failures.isEmpty {
            lines.append("")
            lines.append("Failed:")
            lines.append(contentsOf: failures.map { "\($0.source): \($0.reason)" })
        }
        let alert = NSAlert()
        alert.messageText = "Plugins"
        alert.informativeText = lines.joined(separator: "\n")
        if let window { alert.beginSheetModal(for: window) } else { alert.runModal() }
    }

    // MARK: Closing

    /// - Returns: true when the document may be discarded (asked once per close or quit).
    func confirmClose() -> Bool {
        if closeConfirmed { return true }
        syncText()
        closeConfirmed = session.confirmDiscard()
        updateTitle()
        return closeConfirmed
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        confirmClose()
    }

    func windowWillClose(_ notification: Notification) {
        renderTimer?.invalidate()
        externalChangeTimer?.invalidate()
        appearanceObservation = nil
        session.onExternalChangeSuspected = nil
    }
}

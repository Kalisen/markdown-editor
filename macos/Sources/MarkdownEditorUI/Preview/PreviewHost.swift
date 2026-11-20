import AppKit
import MarkdownEditorCore
import WebKit

/// Owns the WKWebView preview: serves the shell page, plugin folders and the document folder through the
/// `mdeditor://` scheme, and pushes rendered HTML to the page as messages (no page reloads).
@MainActor
final class PreviewHost: NSObject {
    private static let logger = Diagnostics.logger(category: "Preview")

    /// Smallest change of a scroll position worth sending to the page (in lines, or tail progress).
    private static let scrollEpsilon = 0.001
    private static let messageHandlerName = "host"

    /// shared/preview/preview.js talks to its host through WebView2's `window.chrome.webview`; this gives it
    /// the same interface over WebKit message handlers. `__mdeditorDeliver` is how the host posts to the page.
    private static let bridgeScript = """
        (() => {
          const listeners = [];
          window.chrome = window.chrome || {};
          window.chrome.webview = {
            postMessage: (message) => window.webkit.messageHandlers.\(messageHandlerName).postMessage(JSON.stringify(message)),
            addEventListener: (type, listener) => { if (type === 'message') listeners.push(listener); },
          };
          window.__mdeditorDeliver = (data) => { for (const listener of listeners) listener({ data }); };
        })();
        """

    /// Captures the rendered preview (evaluated by the host, not subject to the page's policy).
    private static let snapshotScript = """
        return JSON.stringify({ html: document.getElementById('\(PreviewPageBuilder.contentElementID)').innerHTML,
          styles: Array.from(document.querySelectorAll('link[rel=stylesheet]'), (link) => link.href) });
        """

    /// Before printing, images that were not loaded yet because they are off-screen are loaded.
    private static let loadAllImagesScript = """
        const images = Array.from(document.images);
        for (const image of images) image.loading = 'eager';
        await Promise.race([
          Promise.all(images.map((image) => image.complete ? null : new Promise((done) => { image.onload = image.onerror = done; }))),
          new Promise((done) => setTimeout(done, 5000)),
        ]);
        """

    let webView: PreviewWebView

    var onReady: (() -> Void)?
    /// Called when a preview link targets a Markdown file.
    var onOpenDocumentRequested: ((URL) -> Void)?
    /// Called when user input scrolls the preview.
    var onScrolled: ((ScrollPosition) -> Void)?

    private let plugins: [LoadedPlugin]
    private let previewFolder: URL
    private let schemeHandler = PreviewSchemeHandler()
    private let locator = MarkdownFileLocator()
    private(set) var theme: PreviewTheme
    private var resources: PreviewResources
    private var isReady = false
    private var lastScroll: ScrollPosition?
    private var pendingHTML: String?

    /// - Parameter previewFolder: folder holding `preview.js` and `preview.css`.
    init(plugins: [LoadedPlugin], previewFolder: URL, theme: PreviewTheme) {
        self.plugins = plugins
        self.previewFolder = previewFolder
        self.theme = theme
        resources = Self.makeResources(theme: theme, plugins: plugins, previewFolder: previewFolder, documentFolder: nil)

        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(schemeHandler, forURLScheme: PreviewOrigins.scheme)
        configuration.userContentController.addUserScript(
            WKUserScript(source: Self.bridgeScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        webView = PreviewWebView(frame: .zero, configuration: configuration)
        super.init()

        schemeHandler.resolve = { [weak self] url in self?.resources.resolve(url) }
        configuration.userContentController.add(MessageReceiver(host: self), name: Self.messageHandlerName)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsMagnification = true
        #if DEBUG
        webView.isInspectable = true
        #endif
    }

    private static func makeResources(theme: PreviewTheme, plugins: [LoadedPlugin], previewFolder: URL, documentFolder: URL?) -> PreviewResources {
        let page = PreviewPageBuilder.build(theme: theme, plugins: plugins.map(\.plugin))
        return PreviewResources(page: page, previewFolder: previewFolder, plugins: plugins, documentFolder: documentFolder)
    }

    /// Loads the shell page; `onReady` is called once it can receive content.
    func load() {
        isReady = false
        lastScroll = nil
        webView.load(URLRequest(url: PreviewResources.shellURL))
    }

    /// Switches the page (and the plugins' output) to another theme, which reloads it.
    func setTheme(_ theme: PreviewTheme) {
        guard theme != self.theme else { return }
        self.theme = theme
        resources = Self.makeResources(theme: theme, plugins: plugins, previewFolder: previewFolder, documentFolder: resources.documentFolder)
        load()
    }

    func setDocumentFolder(_ folder: URL?) {
        resources.documentFolder = folder
    }

    func render(_ html: String) {
        guard isReady else {
            pendingHTML = html
            return
        }
        deliver("window.__mdeditorDeliver(html)", arguments: ["html": html])
    }

    /// Scrolls the preview to follow the editor's position.
    func scroll(to position: ScrollPosition) {
        if let last = lastScroll, abs(position.line - last.line) < Self.scrollEpsilon, abs(position.tail - last.tail) < Self.scrollEpsilon { return }
        guard isReady else { return }
        lastScroll = position
        deliver("window.__mdeditorDeliver(JSON.parse(message))", arguments: ["message": PreviewMessages.scrollToLine(position)])
    }

    private func deliver(_ script: String, arguments: [String: Any]) {
        webView.callAsyncJavaScript(script, arguments: arguments, in: nil, in: .page) { result in
            if case .failure(let error) = result {
                // The page was reloaded or its process ended meanwhile: the next render restores the content.
                Self.logger.warning("Preview message not delivered: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: Export

    /// - Returns: the rendered content and stylesheet URLs, or nil when the preview is not ready.
    func snapshot() async -> PreviewSnapshot? {
        guard isReady else { return nil }
        do {
            guard let json = try await webView.callAsyncJavaScript(Self.snapshotScript, arguments: [:], in: nil, contentWorld: .page) as? String,
                  let root = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
                  let html = root["html"] as? String, let styles = root["styles"] as? [String] else { return nil }
            return PreviewSnapshot(contentHTML: html, stylesheetURLs: styles)
        } catch {
            Self.logger.error("Preview snapshot failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// The file a stylesheet URL of the preview is served from.
    func stylesheetFile(_ url: String) -> URL? {
        resources.stylesheetFile(url)
    }

    enum PDFExportOutcome {
        case exported
        case previewNotReady
        case failed
    }

    /// Prints the live preview (print styles force light colours) to a paginated PDF file.
    func exportPDF(to file: URL) async -> PDFExportOutcome {
        guard isReady, let window = webView.window else { return .previewNotReady }
        do {
            _ = try await webView.callAsyncJavaScript(Self.loadAllImagesScript, arguments: [:], in: nil, contentWorld: .page)
        } catch {
            // The PDF is still produced; images that did not load are missing from it.
            Self.logger.warning("Images not preloaded for PDF export: \(error.localizedDescription, privacy: .public)")
        }

        let printInfo = NSPrintInfo(dictionary: [.jobDisposition: NSPrintInfo.JobDisposition.save, .jobSavingURL: file])
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false
        let operation = webView.printOperation(with: printInfo)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        operation.view?.frame = webView.bounds

        let succeeded = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let completion = PrintCompletion { continuation.resume(returning: $0) }
            operation.runModal(for: window, delegate: completion, didRun: #selector(PrintCompletion.printOperationDidRun(_:success:contextInfo:)),
                               contextInfo: Unmanaged.passRetained(completion).toOpaque())
        }
        return succeeded ? .exported : .failed
    }

    // MARK: Messages and links

    fileprivate func received(_ message: WKScriptMessage) {
        // Only the shell page may talk to the host.
        guard message.frameInfo.isMainFrame, message.frameInfo.request.url == PreviewResources.shellURL else { return }
        switch PreviewMessages.parse(message.body as? String) {
        case .ready:
            isReady = true
            if let html = pendingHTML { render(html) }
            pendingHTML = nil
            onReady?()
        case .openLink(let href):
            follow(href)
        case .scrolled(let position):
            lastScroll = nil // the page moved on its own; the next request must go through
            onScrolled?(position)
        case nil:
            break
        }
    }

    private func follow(_ href: String?) {
        switch PreviewLinkPolicy.classify(href, documentFolder: resources.documentFolder) {
        case .openExternal(let url):
            NSWorkspace.shared.open(url)
        case .openDocument(let file):
            // Missing targets (e.g. wikilinks to notes in other folders) are searched under the document folder.
            onOpenDocumentRequested?(locator.locate(file, documentFolder: resources.documentFolder) ?? file)
        case .ignore:
            break
        }
    }
}

extension PreviewHost: WKNavigationDelegate, WKUIDelegate {
    /// The preview only ever shows the shell page; any other navigation is treated as a link click.
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        if navigationAction.request.url == PreviewResources.shellURL, navigationAction.targetFrame?.isMainFrame == true { return .allow }
        if navigationAction.navigationType == .linkActivated { follow(navigationAction.request.url?.absoluteString) }
        return .cancel
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        follow(navigationAction.request.url?.absoluteString)
        return nil
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        Self.logger.warning("Preview process ended; reloading the preview")
        load()
    }
}

/// Forwards page messages without the web view's configuration retaining the host.
private final class MessageReceiver: NSObject, WKScriptMessageHandler {
    private weak var host: PreviewHost?

    init(host: PreviewHost) {
        self.host = host
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        MainActor.assumeIsolated { host?.received(message) }
    }
}

private final class PrintCompletion: NSObject {
    private let completion: (Bool) -> Void

    init(_ completion: @escaping (Bool) -> Void) {
        self.completion = completion
    }

    @objc func printOperationDidRun(_ operation: NSPrintOperation, success: Bool, contextInfo: UnsafeMutableRawPointer?) {
        completion(success)
        // Balances the retain taken for the duration of the print operation.
        if let contextInfo { Unmanaged<PrintCompletion>.fromOpaque(contextInfo).release() }
    }
}

/// The preview's web view. A file dropped on it is handed to the app instead of being navigated to.
final class PreviewWebView: WKWebView {
    var onFilesDropped: (([URL]) -> Void)?

    private func droppedFiles(_ sender: NSDraggingInfo) -> [URL] {
        sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppedFiles(sender).isEmpty ? super.draggingEntered(sender) : .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppedFiles(sender).isEmpty ? super.draggingUpdated(sender) : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let files = droppedFiles(sender)
        guard !files.isEmpty else { return super.performDragOperation(sender) }
        onFilesDropped?(files)
        return true
    }
}

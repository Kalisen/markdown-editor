import CommonMark
import MarkdownEditorCore

/// Picture rendering: resolves relative image paths against the document folder and supports size hints in
/// the image title, e.g. `![alt](a.png "=200x100")`.
public struct ImagesPlugin: MarkdownPlugin, DocumentFeatureProbe {
    public static let pluginID = "images"
    public static let stylesheetPath = "assets/images.css"

    public init() {}

    public var id: String { Self.pluginID }
    public var name: String { "Pictures" }
    public var version: PluginVersion { PluginVersion(1, 0, 0) }
    public var previewAssets: [PreviewAsset] { [.stylesheet(Self.stylesheetPath)] }

    public func isUsed(by document: Document) -> Bool {
        document.hasDescendant(ofType: Image.self)
    }

    public func configurePipeline(_ builder: MarkdownPipelineBuilder) {
        builder.addDocumentProcessor(key: Self.pluginID, Self.rewriteImages)
    }

    static func rewriteImages(in document: Document) {
        for image in document.descendants(ofType: Image.self) {
            image.destination = ImageURLResolver.resolve(image.destination)
            if let hint = ImageSizeHint(title: image.title) {
                image.title = nil
                if let width = hint.width { image.attributes.addProperty("width", String(width)) }
                if let height = hint.height { image.attributes.addProperty("height", String(height)) }
            }
            image.attributes.addProperty("loading", "lazy")
        }
    }
}

/// Size hint written as an image title: "=WxH", "=Wx" or "=xH" (pixels).
struct ImageSizeHint: Equatable {
    let width: Int?
    let height: Int?

    init?(title: String?) {
        // Digit runs are bounded so values always fit in an Int.
        guard let title, let match = title.trimmingCharacters(in: .whitespacesAndNewlines)
            .wholeMatch(of: #/=(?<width>\d{1,5})?x(?<height>\d{1,5})?/#) else { return nil }
        width = match.width.flatMap { Int($0) }
        height = match.height.flatMap { Int($0) }
        if width == nil, height == nil { return nil }
    }
}

/// Maps document-relative image paths to the preview's document origin.
enum ImageURLResolver {
    static func resolve(_ url: String) -> String {
        guard let first = url.first, first != "/", first != "\\", first != "#" else { return url }
        // Absolute URLs (and "c:" drive letters, which read as URL schemes) are left untouched.
        if url.firstMatch(of: #/^[A-Za-z][A-Za-z0-9+.\-]*:/#) != nil { return url }
        var relative = url.replacingOccurrences(of: "\\", with: "/")
        if relative.hasPrefix("./") { relative.removeFirst(2) }
        return PreviewOrigins.documentOrigin + relative
    }
}

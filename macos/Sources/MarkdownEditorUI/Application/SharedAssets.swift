import Foundation

/// The files shared with the Windows app (repository folder `shared`), copied into the app bundle.
struct SharedAssets {
    /// Environment variable pointing at the repository's `shared` folder, for running outside an app bundle.
    static let environmentVariable = "MARKDOWN_EDITOR_SHARED"
    private static let folderName = "shared"

    let root: URL

    /// Folder holding `preview.js` and `preview.css`.
    var previewFolder: URL { root.appendingPathComponent("preview", isDirectory: true) }

    /// Folder holding one folder of assets per plugin id.
    var pluginsFolder: URL { root.appendingPathComponent("plugins", isDirectory: true) }

    /// The assets of the app bundle, or of the folder named by `MARKDOWN_EDITOR_SHARED`; nil when neither exists.
    static func locate(bundle: Bundle = .main, environment: [String: String] = ProcessInfo.processInfo.environment) -> SharedAssets? {
        let candidates = [
            environment[environmentVariable].map { URL(fileURLWithPath: $0, isDirectory: true) },
            bundle.resourceURL?.appendingPathComponent(folderName, isDirectory: true),
        ]
        return candidates.compactMap { $0 }.map(SharedAssets.init).first { $0.isComplete }
    }

    private var isComplete: Bool {
        FileManager.default.fileExists(atPath: previewFolder.appendingPathComponent("preview.js").path)
    }
}

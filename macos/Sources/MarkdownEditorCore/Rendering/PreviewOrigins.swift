import Foundation

/// Virtual origins served to the preview through a custom URL scheme. Relative document resources are
/// reachable under `documentOrigin`; plugin assets under `pluginOrigin`.
public enum PreviewOrigins {
    public static let scheme = "mdeditor"
    public static let documentHost = "doc.mdeditor.local"
    public static let appHost = "app.mdeditor.local"
    public static let pluginHostSuffix = ".plugin.mdeditor.local"

    public static let documentOrigin = "\(scheme)://\(documentHost)/"
    public static let appOrigin = "\(scheme)://\(appHost)/"

    public static func pluginHost(_ pluginID: String) -> String { pluginID + pluginHostSuffix }

    public static func pluginOrigin(_ pluginID: String) -> String { "\(scheme)://\(pluginHost(pluginID))/" }

    /// The plugin a host belongs to, or nil for any other host.
    public static func pluginID(ofHost host: String) -> String? {
        let lowercased = host.lowercased()
        return lowercased.hasSuffix(pluginHostSuffix) ? String(lowercased.dropLast(pluginHostSuffix.count)) : nil
    }
}

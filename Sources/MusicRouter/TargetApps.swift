import AppKit

/// Players the "Media Key Target" feature can aim the keys at. A short
/// allowlist: any app with a dictionary would show up otherwise (browsers
/// are scriptable but don't understand playpause).
enum TargetApps {
    struct App: Equatable {
        let name: String
        let bundleID: String
    }

    static let known: [App] = [
        App(name: "Spotify", bundleID: "com.spotify.client"),
        App(name: "VLC", bundleID: "org.videolan.vlc"),
        App(name: "Vox", bundleID: "com.coppertino.Vox"),
        App(name: "Swinsian", bundleID: "com.swinsian.Swinsian"),
        // no AppleScript dictionary: can only be launched, not controlled
        App(name: "TIDAL", bundleID: "com.tidal.desktop"),
    ]

    static func name(for bundleID: String) -> String {
        known.first { $0.bundleID == bundleID }?.name
            ?? appURL(for: bundleID)?.deletingPathExtension().lastPathComponent
            ?? bundleID
    }

    static func appURL(for bundleID: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    static func isRunning(_ bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    /// Declares an AppleScript dictionary, i.e. understands our verbs at all
    /// (checked on the installed bundle, not by trying).
    static func isScriptable(_ bundleID: String) -> Bool {
        guard let url = appURL(for: bundleID), let info = Bundle(url: url)?.infoDictionary else { return false }
        return info["OSAScriptingDefinition"] != nil || (info["NSAppleScriptEnabled"] as? Bool) == true
    }

    /// Known players that are installed, in `known` order.
    static func installed() -> [App] {
        known.filter { appURL(for: $0.bundleID) != nil }
    }

    static func running() -> [App] {
        known.filter { isRunning($0.bundleID) }
    }

    /// Next stop of "Automatic → each running player → Automatic". A current
    /// target that isn't running starts over at the first running player.
    static func nextTarget(after current: String?, running: [String]) -> String? {
        let order: [String?] = [nil] + running
        guard let current, let index = order.firstIndex(where: { $0 == current }) else {
            return running.first
        }
        return order[(index + 1) % order.count]
    }
}

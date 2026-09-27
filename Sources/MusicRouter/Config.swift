import AppKit

/// Config in standard `defaults`, editable from the menu bar or terminal:
///
///   defaults write dev.drumandbytes.musicrouter replacement /Applications/Spotify.app
///   defaults write dev.drumandbytes.musicrouter replacement https://music.youtube.com/
///   defaults delete dev.drumandbytes.musicrouter replacement   # block only, no redirect
enum Config {
    static let domain = "dev.drumandbytes.musicrouter"

    // .standard, not suiteName: domain is our own bundle ID

    /// App path or URL to open instead of Music.app. `nil` = block only (noTunes default).
    static var replacement: String? {
        get { UserDefaults.standard.string(forKey: "replacement") }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: "replacement")
            } else {
                UserDefaults.standard.removeObject(forKey: "replacement")
            }
        }
    }

    /// Set once the permission prompt has shown; later launches poll silently.
    static var hasRequestedPermissions: Bool {
        get { UserDefaults.standard.bool(forKey: "hasRequestedPermissions") }
        set { UserDefaults.standard.set(newValue, forKey: "hasRequestedPermissions") }
    }

    /// Menu bar icon hidden. Relaunching un-hides it.
    static var menuBarIconHidden: Bool {
        get { UserDefaults.standard.bool(forKey: "menuBarIconHidden") }
        set { UserDefaults.standard.set(newValue, forKey: "menuBarIconHidden") }
    }

    /// Defaults to true, hence `object(forKey:)`. Persisted, or switching off
    /// silently undid itself at the next login.
    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "enabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "enabled") }
    }

    /// Shortcuts for the "Replacement App" menu. Native apps only if installed.
    static let predefinedApps: [(name: String, target: String)] = [
        (name: "Spotify", target: "/Applications/Spotify.app"),
        (name: "TIDAL", target: "/Applications/TIDAL.app"),
        (name: "VLC", target: "/Applications/VLC.app"),
        (name: "YouTube Music", target: "https://music.youtube.com/"),
        (name: "Deezer", target: "https://www.deezer.com/"),
        (name: "SoundCloud", target: "https://soundcloud.com/"),
    ]

    /// Installed native apps + all web players, in `predefinedApps` order.
    static var availablePredefinedApps: [(name: String, target: String)] {
        predefinedApps.filter { isWebURL($0.target) || FileManager.default.fileExists(atPath: $0.target) }
    }

    /// Configured native app since uninstalled/moved. Both launch paths fail
    /// silently then, so the menu flags it.
    static var replacementIsMissing: Bool {
        guard let replacement, !isWebURL(replacement) else { return false }
        return !FileManager.default.fileExists(atPath: replacement)
    }

    static func isWebURL(_ target: String) -> Bool {
        guard let url = URL(string: target), let scheme = url.scheme else { return false }
        return scheme.hasPrefix("http")
    }

    /// Opens the replacement, if any. Shared by `MusicLauncherGuard` and `MediaKeyTap`'s handler.
    static func openReplacement() {
        guard let replacement else { return }

        if isWebURL(replacement) {
            NSWorkspace.shared.open(URL(string: replacement)!)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: replacement))
        }
    }
}

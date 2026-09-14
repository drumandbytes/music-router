import AppKit

/// User-facing configuration, stored as standard macOS `defaults` — readable/
/// writable from the menu bar (see `StatusBarController`) or the terminal:
///
///   defaults write dev.drumandbytes.musicrouter replacement /Applications/Spotify.app
///   defaults write dev.drumandbytes.musicrouter replacement https://music.youtube.com/
///   defaults delete dev.drumandbytes.musicrouter replacement   # block only, no redirect
enum Config {
    static let domain = "dev.drumandbytes.musicrouter"

    // NOT UserDefaults(suiteName: domain) — that's for sharing defaults with
    // a *different* bundle ID (extensions, app groups). Since domain here is
    // this app's own bundle ID, UserDefaults.standard already reads/writes
    // exactly ~/Library/Preferences/dev.drumandbytes.musicrouter.plist.

    /// App path or URL to open instead of Music.app/iTunes. `nil` means
    /// block-only, matching noTunes' default behavior.
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

    /// Set once the permission prompt has been shown, so it only ever
    /// interrupts the user on first launch — later launches poll silently
    /// (see `AppDelegate`) instead of re-alerting every time.
    static var hasRequestedPermissions: Bool {
        get { UserDefaults.standard.bool(forKey: "hasRequestedPermissions") }
        set { UserDefaults.standard.set(newValue, forKey: "hasRequestedPermissions") }
    }

    /// Whether the menu bar icon is hidden (see `StatusBarController`).
    /// Relaunching the app while this is true un-hides it again.
    static var menuBarIconHidden: Bool {
        get { UserDefaults.standard.bool(forKey: "menuBarIconHidden") }
        set { UserDefaults.standard.set(newValue, forKey: "menuBarIconHidden") }
    }

    /// A curated shortcut list for the "Replacement App" menu. Native apps
    /// are filtered to ones actually installed; web players always show
    /// since there's nothing to check. "Choose App…" covers anything else.
    struct PredefinedApp {
        let name: String
        let target: String
    }

    static let predefinedApps: [PredefinedApp] = [
        PredefinedApp(name: "Spotify", target: "/Applications/Spotify.app"),
        PredefinedApp(name: "TIDAL", target: "/Applications/TIDAL.app"),
        PredefinedApp(name: "VLC", target: "/Applications/VLC.app"),
        PredefinedApp(name: "YouTube Music", target: "https://music.youtube.com/"),
        PredefinedApp(name: "Deezer", target: "https://www.deezer.com/"),
        PredefinedApp(name: "SoundCloud", target: "https://soundcloud.com/"),
    ]

    /// Installed native apps + all web players, in `predefinedApps` order.
    static var availablePredefinedApps: [PredefinedApp] {
        predefinedApps.filter { isWebURL($0.target) || FileManager.default.fileExists(atPath: $0.target) }
    }

    /// Pure so it's directly testable — `open` needs no live app/URL to be
    /// valid, just the string shape.
    static func isWebURL(_ target: String) -> Bool {
        guard let url = URL(string: target), let scheme = url.scheme else { return false }
        return scheme.hasPrefix("http")
    }

    /// Opens the configured replacement app/URL, if any — shared by both
    /// `MusicLauncherGuard` (launch-then-kill path) and `MediaKeyTap`'s
    /// handler (root-level intercept path), since both need to react the
    /// same way once Music.app has been kept from taking the play command.
    static func openReplacement() {
        guard let replacement else { return }

        if isWebURL(replacement) {
            NSWorkspace.shared.open(URL(string: replacement)!)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: replacement))
        }
    }
}

import Foundation

/// Sends playpause/next/previous to a scriptable app (Spotify, VLC, Music) via
/// in-process `NSAppleScript`, so no fork/exec on the media-key hot path.
enum AppleScriptRemote {
    static func verb(for key: MediaKeyTap.MediaKey) -> String {
        switch key {
        case .playPause: return "playpause"
        case .next: return "next track"
        case .previous: return "previous track"
        }
    }

    /// `tell application` auto-launches the target. `false` means the app
    /// doesn't understand the command (no dictionary); caller falls back to open.
    ///
    /// ponytail: synchronous AppleEvent call on the main thread — could
    /// briefly stall the menu if the target app is hung. Move to a
    /// background queue with a timeout if that's ever observed in practice.
    static func send(_ key: MediaKeyTap.MediaKey, toAppAtPath path: String) -> Bool {
        run("tell application \"\(path)\" to \(verb(for: key))")
    }

    /// Caller must have checked the app is running: this would launch it.
    static func send(_ key: MediaKeyTap.MediaKey, toBundleID bundleID: String) -> Bool {
        run(source(for: key, bundleID: bundleID))
    }

    static func source(for key: MediaKeyTap.MediaKey, bundleID: String) -> String {
        "tell application id \"\(bundleID)\" to \(verb(for: key))"
    }

    private static func run(_ source: String) -> Bool {
        guard let script = NSAppleScript(source: source) else { return false }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        return error == nil
    }
}

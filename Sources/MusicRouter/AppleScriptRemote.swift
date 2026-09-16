import Foundation

/// Sends a real playback command to a scriptable app (Spotify, VLC, Music —
/// all share iTunes' old `playpause`/`next track`/`previous track` verbs),
/// instead of just opening/focusing it. Runs in-process via `NSAppleScript`
/// rather than shelling out to `osascript`, so there's no fork/exec on the
/// media-key hot path — just a one-line script compile + an AppleEvent
/// round-trip, a few ms at most.
enum AppleScriptRemote {
    static func verb(for key: MediaKeyTap.MediaKey) -> String {
        switch key {
        case .playPause: return "playpause"
        case .next: return "next track"
        case .previous: return "previous track"
        }
    }

    /// `tell application <path>` auto-launches the app if it isn't running,
    /// so this doubles as the launch step too — returns `false` (letting the
    /// caller fall back to a plain open) only when the app doesn't
    /// understand the command at all, e.g. it has no AppleScript dictionary.
    ///
    /// ponytail: synchronous AppleEvent call on the main thread — could
    /// briefly stall the menu if the target app is hung. Move to a
    /// background queue with a timeout if that's ever observed in practice.
    static func send(_ key: MediaKeyTap.MediaKey, toAppAtPath path: String) -> Bool {
        let source = "tell application \"\(path)\" to \(verb(for: key))"
        guard let script = NSAppleScript(source: source) else { return false }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        return error == nil
    }
}

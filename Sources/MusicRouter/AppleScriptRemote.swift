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
        let source = "tell application \"\(path)\" to \(verb(for: key))"
        guard let script = NSAppleScript(source: source) else { return false }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        return error == nil
    }
}

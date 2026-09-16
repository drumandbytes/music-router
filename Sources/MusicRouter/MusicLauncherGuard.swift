import AppKit

/// Watches for Music.app/iTunes launches triggered by media keys, AirPlay,
/// Handoff, or Siri, and kills them immediately — optionally opening a
/// replacement app or URL instead.
///
/// This can't prevent the launch itself (no public veto hook exists for
/// AirPlay/Handoff/Siri-triggered launches), only react to it as fast as
/// possible. `MediaKeyTap` handles the one trigger (physical media keys)
/// where the launch can actually be prevented at the source.
final class MusicLauncherGuard {
    private static let blockedBundleIDs: Set<String> = [
        "com.apple.Music",
        "com.apple.iTunes",
    ]

    private var observer: NSObjectProtocol?

    func start() {
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleLaunch(notification)
        }
    }

    func stop() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observer = nil
    }

    /// Pure so it's directly testable without a real `NSRunningApplication`
    /// (no public initializer, so one can't be constructed in a test).
    static func shouldBlock(bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return blockedBundleIDs.contains(bundleID)
    }

    private func handleLaunch(_ notification: Notification) {
        guard
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
            Self.shouldBlock(bundleID: app.bundleIdentifier)
        else { return }

        // Replacement first, terminate second — cuts down how long Music is
        // visibly on screen before it takes over. (Could react even earlier
        // via willLaunchApplicationNotification, but the app may not have a
        // live process yet at that point, so forceTerminate() isn't
        // guaranteed to work there — not worth it for the extra flicker.)
        Config.openReplacement()
        app.forceTerminate()
    }
}

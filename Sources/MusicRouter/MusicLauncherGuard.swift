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

    private func handleLaunch(_ notification: Notification) {
        guard
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
            let bundleID = app.bundleIdentifier,
            Self.blockedBundleIDs.contains(bundleID)
        else { return }

        // Open the replacement first, terminate second — `forceTerminate()`
        // doesn't block on Music actually finishing quitting, but ordering
        // it after openReplacement noticeably shortens how long Music is
        // visibly on screen before the replacement takes over.
        //
        // `willLaunchApplicationNotification` fires earlier (before Music
        // is visible at all), but at that point the NSRunningApplication
        // may not have a live process yet, so forceTerminate() isn't
        // reliably guaranteed to work — not worth the risk over the flicker
        // this already cuts down.
        Config.openReplacement()
        app.forceTerminate()
    }
}

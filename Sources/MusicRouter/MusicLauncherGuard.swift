import AppKit

/// Kills Music.app/iTunes launched by media keys, AirPlay, Handoff or Siri,
/// optionally opening a replacement. Can only react, not veto; `MediaKeyTap`
/// prevents the media-key case at the source.
final class MusicLauncherGuard {
    private static let blockedBundleIDs: Set<String> = [
        "com.apple.Music",
        "com.apple.iTunes",
    ]

    private var observer: NSObjectProtocol?

    func start() {
        // idempotent: a second start would orphan the observer and double-fire forceTerminate()
        guard observer == nil else { return }
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

    /// Pure: `NSRunningApplication` has no public init to test with.
    static func shouldBlock(bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return blockedBundleIDs.contains(bundleID)
    }

    private func handleLaunch(_ notification: Notification) {
        guard
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
            Self.shouldBlock(bundleID: app.bundleIdentifier)
        else { return }

        // replacement first to shorten Music's time on screen; willLaunch is
        // earlier but forceTerminate() isn't reliable there yet
        Config.openReplacement()
        app.forceTerminate()
    }
}

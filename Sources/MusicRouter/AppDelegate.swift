import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let launcherGuard = MusicLauncherGuard()
    private let nowPlayingObserver = NowPlayingObserver()
    private var mediaKeyTap: MediaKeyTap?
    private var statusBar: StatusBarController?
    private var permissionCheckTimer: Timer?
    private var hasRequestedAccessibility = false
    private var lastKeySwallowed = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let tap = MediaKeyTap { [weak self] key, isPressed in
            self?.shouldSwallow(key, isPressed: isPressed) ?? false
        }
        mediaKeyTap = tap

        if !tap.hasPermission {
            // prompt once ever; after that, poll silently
            if !Config.hasRequestedPermissions {
                tap.requestInputMonitoringPermission()
                Config.hasRequestedPermissions = true
            }
            // Only sequences the second prompt; must never start the tap itself
            // (it once did, re-arming a disabled app). The tap self-installs
            // once both grants exist.
            permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
                guard let self, let tap = self.mediaKeyTap else { timer.invalidate(); return }
                if tap.hasPermission {
                    timer.invalidate()
                    self.permissionCheckTimer = nil
                } else if tap.hasInputMonitoring, !self.hasRequestedAccessibility {
                    // Input Monitoring granted; safe to prompt for Accessibility without collision
                    tap.requestAccessibilityPermission()
                    self.hasRequestedAccessibility = true
                }
            }
        }

        setEnabled(Config.isEnabled)

        let statusBar = StatusBarController()
        statusBar.onToggle = { [weak self] enabled in
            self?.setEnabled(enabled)
        }
        self.statusBar = statusBar
    }

    // else the media-control child outlives us
    func applicationWillTerminate(_ notification: Notification) {
        nowPlayingObserver.stop()
    }

    // Catches every "opened while running" (Finder, `open`), unlike
    // applicationDidBecomeActive, which missed most reopens in testing.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusBar?.unhideIfNeeded()
        return true
    }

    /// Decides whether `MediaKeyTap` swallows the event, and launches/controls the replacement if so.
    private func shouldSwallow(_ key: MediaKeyTap.MediaKey, isPressed: Bool) -> Bool {
        let swallow = Self.decideSwallow(
            isPressed: isPressed,
            isSomethingOpen: nowPlayingObserver.isSomethingOpen,
            lastKeySwallowed: lastKeySwallowed
        )
        if isPressed {
            lastKeySwallowed = swallow
            if swallow { handleMediaKey(key) }
        }
        return swallow
    }

    /// Swallow (and redirect) only when nothing owns Now Playing; otherwise let
    /// macOS route it. Releases mirror the press so no stray key-up leaks.
    static func decideSwallow(isPressed: Bool, isSomethingOpen: Bool, lastKeySwallowed: Bool) -> Bool {
        guard isPressed else { return lastKeySwallowed }
        return !isSomethingOpen
    }

    private func handleMediaKey(_ key: MediaKeyTap.MediaKey) {
        // nothing playing: launch the replacement, AppleScript-forcing play
        // where it can; plain open for web players and unscriptable apps
        if let replacement = Config.replacement,
           !Config.isWebURL(replacement),
           AppleScriptRemote.send(key, toAppAtPath: replacement) {
            return
        }
        Config.openReplacement()
    }

    private func setEnabled(_ enabled: Bool) {
        if enabled {
            launcherGuard.start()
            nowPlayingObserver.start()
            mediaKeyTap?.start()
        } else {
            launcherGuard.stop()
            nowPlayingObserver.stop()
            mediaKeyTap?.stop()
        }
    }
}

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
            // Only show the actual system prompts once ever — re-nagging on
            // every launch while the user hasn't gotten to Settings yet is
            // annoying. After that, just poll silently.
            if !Config.hasRequestedPermissions {
                tap.requestInputMonitoringPermission()
                Config.hasRequestedPermissions = true
            }
            // Only sequences the second prompt. It must never start the tap
            // itself: it used to, ignoring enabled state, so granting
            // permission while the app was switched off re-armed it anyway.
            // A started tap installs itself once both grants exist.
            permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
                guard let self, let tap = self.mediaKeyTap else { timer.invalidate(); return }
                if tap.hasPermission {
                    timer.invalidate()
                    self.permissionCheckTimer = nil
                } else if tap.hasInputMonitoring, !self.hasRequestedAccessibility {
                    // Input Monitoring is confirmed granted now, so it's safe
                    // to prompt for Accessibility next without the two
                    // prompts colliding.
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

    // Without this, quitting leaves the media-control child process orphaned
    // and running forever instead of exiting with its parent.
    func applicationWillTerminate(_ notification: Notification) {
        nowPlayingObserver.stop()
    }

    // The documented hook for "user tried to open the app again while it's
    // already running" (double-clicking it in Finder, `open` from Terminal,
    // etc. — not just Dock icon clicks). Confirmed empirically (3/3 clean
    // runs) over applicationDidBecomeActive, which only fires when
    // activation state actually changes and missed most reopens.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusBar?.unhideIfNeeded()
        return true
    }

    /// Decides whether `MediaKeyTap` should swallow the event, and fires the
    /// side effect (launching/controlling the replacement) when it does.
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

    /// Pure so it's directly testable without a real `NowPlayingObserver`.
    /// Release events mirror whatever was decided for the press, so a
    /// swallowed press can't leave a stray key-up passed through to the OS
    /// (or vice versa) — `isSomethingOpen` could in theory change between
    /// the two, though not in the sub-second window between a real press
    /// and release. When pressed, swallow (and redirect) exactly when
    /// nothing already owns Now Playing — otherwise back off and let
    /// macOS's native routing reach it directly, as it would if this app
    /// didn't exist.
    static func decideSwallow(isPressed: Bool, isSomethingOpen: Bool, lastKeySwallowed: Bool) -> Bool {
        guard isPressed else { return lastKeySwallowed }
        return !isSomethingOpen
    }

    private func handleMediaKey(_ key: MediaKeyTap.MediaKey) {
        // Nothing's playing yet, so there's no existing Now Playing session
        // to send a command to — launch the configured replacement instead.
        // For a scriptable native app, force it into a playing state via
        // AppleScript rather than just opening a window; falls back to a
        // plain open for web replacements (can't script a browser tab) and
        // for native apps with no AppleScript dictionary.
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

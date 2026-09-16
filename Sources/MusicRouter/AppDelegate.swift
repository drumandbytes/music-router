import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let launcherGuard = MusicLauncherGuard()
    private var mediaKeyTap: MediaKeyTap?
    private var statusBar: StatusBarController?
    private var permissionCheckTimer: Timer?
    private var hasRequestedAccessibility = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let tap = MediaKeyTap { [weak self] key, isPressed in
            guard isPressed else { return }
            self?.handleMediaKey(key)
        }
        mediaKeyTap = tap

        if tap.hasPermission {
            tap.start()
        } else {
            // Only show the actual system prompts once ever — re-nagging on
            // every launch while the user hasn't gotten to Settings yet is
            // annoying. After that, just poll silently.
            if !Config.hasRequestedPermissions {
                tap.requestInputMonitoringPermission()
                Config.hasRequestedPermissions = true
            }
            permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
                guard let self, let tap = self.mediaKeyTap else { timer.invalidate(); return }
                if tap.hasPermission {
                    tap.start()
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

        launcherGuard.start()

        let statusBar = StatusBarController()
        statusBar.onToggle = { [weak self] enabled in
            self?.setEnabled(enabled)
        }
        self.statusBar = statusBar
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

    private func handleMediaKey(_ key: MediaKeyTap.MediaKey) {
        // Phase 1: the key press is swallowed (Music.app never launches for
        // it at all), so open the configured replacement in its place — same
        // behavior as the launch-then-kill path, just without the flicker.
        //
        // TODO(phase 2): once more than one app is playing, route to
        // whichever is actually "Now Playing" instead of always the fixed
        // replacement, via the MediaRemote adapter technique (see README) —
        // and forward play/pause/next/previous specifically, not just "open".
        Config.openReplacement()
    }

    private func setEnabled(_ enabled: Bool) {
        if enabled {
            launcherGuard.start()
            mediaKeyTap?.start()
        } else {
            launcherGuard.stop()
            mediaKeyTap?.stop()
        }
    }
}

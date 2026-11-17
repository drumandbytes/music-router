import AppKit
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let launcherGuard = MusicLauncherGuard()
    private let nowPlayingObserver = NowPlayingObserver()
    private var mediaKeyTap: MediaKeyTap?
    private var statusBar: StatusBarController?
    private var permissionCheckTimer: Timer?
    private var hasRequestedAccessibility = false
    private var lastKeySwallowed = false
    private var cycleHotKey: GlobalHotKey?

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
        applyCycleShortcut()

        let statusBar = StatusBarController()
        statusBar.onToggle = { [weak self] enabled in
            self?.setEnabled(enabled)
        }
        statusBar.onCycleShortcutChanged = { [weak self] in self?.applyCycleShortcut() ?? true }
        statusBar.onShortcutRecording = { [weak self] in self?.setShortcutRecording($0) }
        statusBar.nowPlayingHealth = { [weak self] in self?.nowPlayingObserver.health ?? .starting }
        self.statusBar = statusBar
    }

    // else the adapter child outlives us
    func applicationWillTerminate(_ notification: Notification) {
        nowPlayingObserver.stop()
    }

    // Catches every "opened while running" (Finder, `open`), unlike
    // applicationDidBecomeActive, which missed most reopens in testing.
    // Works with the menu bar icon hidden, so it's the way back to settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusBar?.showSettings()
        return true
    }

    /// Decides whether `MediaKeyTap` swallows the event, and launches/controls the replacement if so.
    private func shouldSwallow(_ key: MediaKeyTap.MediaKey, isPressed: Bool) -> Bool {
        // A chosen scriptable player always gets the keys, whatever owns Now Playing.
        if let target = Self.driveTarget(selected: Config.targetApp, isScriptable: TargetApps.isScriptable) {
            let swallow = Self.decideSwallow(isPressed: isPressed, isSomethingOpen: false, lastKeySwallowed: lastKeySwallowed)
            if isPressed {
                lastKeySwallowed = swallow
                DebugLog.shared.log("key=\(key) target=\(target) swallowed=\(swallow)")
                sendToTarget(key, bundleID: target)
            }
            return swallow
        }
        // read once: with the audio fallback the answer can change between reads
        let isSomethingOpen = nowPlayingObserver.isSomethingOpen
        let swallow = Self.decideSwallow(
            isPressed: isPressed,
            isSomethingOpen: isSomethingOpen,
            lastKeySwallowed: lastKeySwallowed
        )
        if isPressed {
            lastKeySwallowed = swallow
            DebugLog.shared.log("key=\(key) open=\(isSomethingOpen) swallowed=\(swallow)")
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

    /// The selected target when we can actually control it. A target without a
    /// dictionary (TIDAL) can't take keys, so it doesn't intercept; it's only
    /// launched when nothing plays (see `handleMediaKey`).
    static func driveTarget(selected: String?, isScriptable: (String) -> Bool) -> String? {
        guard let selected, isScriptable(selected) else { return nil }
        return selected
    }

    /// Sends to the target if running; otherwise launches it by path (which
    /// AppleScript does implicitly) so the first press starts playback.
    private func sendToTarget(_ key: MediaKeyTap.MediaKey, bundleID: String) {
        if TargetApps.isRunning(bundleID) {
            let sent = AppleScriptRemote.send(key, toBundleID: bundleID)
            DebugLog.shared.log("target=\(bundleID) sent=\(sent)")
        } else if let url = TargetApps.appURL(for: bundleID) {
            let sent = AppleScriptRemote.send(key, toAppAtPath: url.path)
            DebugLog.shared.log("target=\(bundleID) launched sent=\(sent)")
            if !sent { NSWorkspace.shared.open(url) }
        }
    }

    /// App to resume instead of the replacement: the last one that played, if
    /// the setting is on, it's still running, and it isn't Music or ourselves.
    static func resumeTarget(
        enabled: Bool,
        lastPlaying: String?,
        isRunning: (String) -> Bool
    ) -> String? {
        guard enabled, let id = lastPlaying,
              id != Bundle.main.bundleIdentifier,
              !MusicLauncherGuard.shouldBlock(bundleID: id),
              isRunning(id)
        else { return nil }
        return id
    }

    private func handleMediaKey(_ key: MediaKeyTap.MediaKey) {
        if let id = Self.resumeTarget(
            enabled: Config.resumeLastPlayer,
            lastPlaying: nowPlayingObserver.lastPlayingBundleID,
            isRunning: { !NSRunningApplication.runningApplications(withBundleIdentifier: $0).isEmpty }
        ) {
            let sent = AppleScriptRemote.send(key, toBundleID: id)
            DebugLog.shared.log("resume lastPlaying=\(id) sent=\(sent)")
            if sent { return }
        }
        // a chosen but unscriptable target (TIDAL) is launched instead of the replacement
        if let selected = Config.targetApp, let url = TargetApps.appURL(for: selected) {
            DebugLog.shared.log("launch target=\(selected)")
            NSWorkspace.shared.open(url)
            return
        }
        // nothing playing: launch the replacement, AppleScript-forcing play
        // where it can; plain open for web players and unscriptable apps
        if let replacement = Config.replacement,
           !Config.isWebURL(replacement),
           AppleScriptRemote.send(key, toAppAtPath: replacement) {
            return
        }
        Config.openReplacement()
    }

    /// Registers the configured cycle shortcut; re-run when it or the toggle
    /// changes. `false` = enabled but couldn't register (usually taken by another app).
    @discardableResult
    func applyCycleShortcut() -> Bool {
        cycleHotKey?.unregister()
        cycleHotKey = nil
        guard Config.cycleShortcut else {
            DebugLog.shared.log("cycle shortcut off")
            return true
        }
        let shortcut = Config.cycleShortcutBinding
        cycleHotKey = GlobalHotKey(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers) { [weak self] in
            self?.cycleTarget()
        }
        DebugLog.shared.log("cycle shortcut \(shortcut.display) " + (cycleHotKey == nil ? "registration failed" : "registered"))
        return cycleHotKey != nil
    }

    /// While the recorder listens, the current hotkey must not swallow the press.
    private func setShortcutRecording(_ recording: Bool) {
        DebugLog.shared.log("shortcut recording=\(recording)")
        if recording {
            cycleHotKey?.unregister()
            cycleHotKey = nil
        } else {
            applyCycleShortcut()
        }
    }

    private func cycleTarget() {
        let next = TargetApps.nextTarget(after: Config.targetApp, running: TargetApps.running().map(\.bundleID).filter(TargetApps.isScriptable))
        Config.targetApp = next
        let label = next.map(TargetApps.name(for:)) ?? "Automatic"
        DebugLog.shared.log("target cycled to \(next ?? "automatic")")
        statusBar?.flash(label)
        if Config.showTargetToast {
            Toast.shared.show(Toast.targetContent(bundleID: next))
        }
    }

    private func setEnabled(_ enabled: Bool) {
        DebugLog.shared.log("enabled=\(enabled)")
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

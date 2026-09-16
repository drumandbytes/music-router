import AppKit
import ApplicationServices
import CoreGraphics
import ServiceManagement
import UniformTypeIdentifiers

/// Menu bar icon: shows current state, lets you toggle blocking, pick a
/// replacement app, enable launch-at-login, hide the icon, and quit.
final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var isEnabled = Config.isEnabled
    private var replacementItem: NSMenuItem?
    private var permissionsItem: NSMenuItem?
    var onToggle: ((Bool) -> Void)?

    override init() {
        super.init()
        statusItem.button?.image = NSImage(
            systemSymbolName: "music.quarternote.3",
            accessibilityDescription: "Music Router"
        )
        statusItem.menu = buildMenu()
        updateIcon()
        unhideIfNeeded()
    }

    // appearsDisabled dims the button image natively — no separate
    // "off" icon asset needed.
    private func updateIcon() {
        statusItem.button?.appearsDisabled = !isEnabled
    }

    /// A hidden `NSStatusItem` has no menu of its own to undo the hide from,
    /// so relaunching the app (fresh launch or reopening a running instance)
    /// is the only way back — called from both.
    func unhideIfNeeded() {
        guard Config.menuBarIconHidden else { return }
        Config.menuBarIconHidden = false
        statusItem.isVisible = true
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let toggleItem = NSMenuItem(
            title: "Enabled",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        toggleItem.target = self
        toggleItem.state = isEnabled ? .on : .off
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        // Submenu is filled in menuWillOpen, so it's always current.
        let replacementItem = NSMenuItem(title: "Replacement App", action: nil, keyEquivalent: "")
        replacementItem.submenu = NSMenu()
        menu.addItem(replacementItem)
        self.replacementItem = replacementItem

        let loginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)

        let hideItem = NSMenuItem(
            title: "Hide Menu Bar Icon",
            action: #selector(hideMenuBarIcon),
            keyEquivalent: ""
        )
        hideItem.target = self
        menu.addItem(hideItem)

        // One line, refreshed in menuWillOpen — surfaces the dual Input
        // Monitoring + Accessibility requirement (undocumented by Apple,
        // easy to half-grant) instead of leaving a silent, unexplained
        // "media keys don't work" as the only symptom. Always clickable:
        // resetting is a harmless no-op to re-confirm when already granted.
        let permissionsItem = NSMenuItem(title: "", action: #selector(resetPermissions), keyEquivalent: "")
        permissionsItem.target = self
        menu.addItem(permissionsItem)
        self.permissionsItem = permissionsItem

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(
            title: "About Music Router",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        let helpItem = NSMenuItem(
            title: "Help",
            action: #selector(showHelp),
            keyEquivalent: ""
        )
        helpItem.target = self
        menu.addItem(helpItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "Quit Music Router",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        menu.delegate = self
        return menu
    }

    /// Refreshes state-dependent items right before the menu shows, rather
    /// than only at launch — a permission granted in System Settings, or a
    /// replacement app installed/uninstalled while this runs, shows up
    /// without quitting and reopening the app.
    func menuWillOpen(_ menu: NSMenu) {
        replacementItem?.submenu = buildReplacementMenu()

        let inputMonitoring = CGPreflightListenEventAccess() ? "✓" : "✗"
        let accessibility = AXIsProcessTrusted() ? "✓" : "✗"
        // "Accessibility" was renamed "Device Control and Data Access" in
        // macOS 27 — same underlying permission, so both names are shown
        // rather than picking one that's wrong on half of supported macOS.
        permissionsItem?.title = "Reset Permissions (Input Monitoring \(inputMonitoring), Accessibility/Device Control \(accessibility))"
    }

    private func buildReplacementMenu() -> NSMenu {
        let submenu = NSMenu()
        let current = Config.replacement

        let blockOnlyItem = NSMenuItem(
            title: "Block Only (no redirect)",
            action: #selector(setBlockOnly),
            keyEquivalent: ""
        )
        blockOnlyItem.target = self
        blockOnlyItem.state = current == nil ? .on : .off
        submenu.addItem(blockOnlyItem)

        submenu.addItem(.separator())

        let available = Config.availablePredefinedApps
        for app in available {
            let title = Config.isWebURL(app.target) ? "\(app.name) (Web)" : app.name
            let item = NSMenuItem(
                title: title,
                action: #selector(selectPredefinedApp(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = app.target
            item.state = current == app.target ? .on : .off
            submenu.addItem(item)
        }

        // Checked against what's actually listed above, not the full
        // predefined list: a predefined app that's since been uninstalled is
        // filtered out of the list, so checking the unfiltered one left the
        // menu showing no selection at all.
        if let current, !available.contains(where: { $0.target == current }) {
            let label = Config.isWebURL(current) ? current : (current as NSString).lastPathComponent
            let suffix = Config.replacementIsMissing ? " (not found)" : ""
            let currentItem = NSMenuItem(title: "Current: \(label)\(suffix)", action: nil, keyEquivalent: "")
            currentItem.state = .on
            currentItem.isEnabled = false
            submenu.addItem(currentItem)
        }

        submenu.addItem(.separator())

        let chooseItem = NSMenuItem(
            title: "Choose App…",
            action: #selector(chooseReplacementApp),
            keyEquivalent: ""
        )
        chooseItem.target = self
        submenu.addItem(chooseItem)

        let customURLItem = NSMenuItem(
            title: "Custom URL…",
            action: #selector(chooseCustomURL),
            keyEquivalent: ""
        )
        customURLItem.target = self
        submenu.addItem(customURLItem)

        return submenu
    }

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        isEnabled.toggle()
        Config.isEnabled = isEnabled
        sender.state = isEnabled ? .on : .off
        updateIcon()
        onToggle?(isEnabled)
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("MusicRouter: failed to toggle login item: \(error)")
        }
        sender.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func hideMenuBarIcon() {
        Config.menuBarIconHidden = true
        statusItem.isVisible = false
    }

    @objc private func setBlockOnly() {
        Config.replacement = nil
    }

    @objc private func selectPredefinedApp(_ sender: NSMenuItem) {
        guard let target = sender.representedObject as? String else { return }
        Config.replacement = target
    }

    @objc private func chooseReplacementApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        Config.replacement = url.path
    }

    @objc private func chooseCustomURL() {
        let alert = NSAlert()
        alert.messageText = "Custom Replacement URL"
        alert.informativeText = "Opened instead of Music.app, e.g. a web player not in the list above."
        alert.addButton(withTitle: "Set")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.placeholderString = "https://example.com/player"
        if let current = Config.replacement, Config.isWebURL(current) {
            field.stringValue = current
        }
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Config.isWebURL(text) else {
            let error = NSAlert()
            error.alertStyle = .warning
            error.messageText = "Not a Web URL"
            error.informativeText = "“\(text)” needs to start with http:// or https://. Use Choose App… for a local app."
            error.runModal()
            return
        }
        Config.replacement = text
    }

    /// Clears both TCC grants for this app's bundle ID so they can be
    /// re-requested cleanly — the fix for the grant silently going stale
    /// after a rebuild changes the app's code-signing identity (see README).
    /// Also clears `hasRequestedPermissions` so the relaunched process
    /// actually re-prompts instead of just polling silently forever, then
    /// relaunches itself — a fresh process is required for the OS to
    /// re-evaluate the (now cleared) grants, and leaving that step to the
    /// user manually is a step they can just forget.
    @objc private func resetPermissions() {
        let confirm = NSAlert()
        confirm.messageText = "Reset Permissions?"
        confirm.informativeText = "Clears the Input Monitoring and Accessibility/Device Control grants for Music Router and relaunches it so you can grant them again."
        confirm.addButton(withTitle: "Reset")
        confirm.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard confirm.runModal() == .alertFirstButtonReturn else { return }

        for service in ["ListenEvent", "Accessibility"] {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            process.arguments = ["reset", service, Config.domain]
            try? process.run()
            process.waitUntilExit()
        }
        Config.hasRequestedPermissions = false

        // `-n` forces a genuinely new process — without it, `open` sees the
        // bundle already running and just re-activates this same instance,
        // which then immediately quits from terminate() below instead of
        // being replaced by a fresh one.
        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        relaunch.arguments = ["-n", Bundle.main.bundleURL.path]
        try? relaunch.run()
        NSApp.terminate(nil)
    }

    @objc private func showAbout() {
        // Accessory apps (no Dock icon) don't auto-activate — without this
        // the panel can open behind whatever's currently frontmost.
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func showHelp() {
        NSWorkspace.shared.open(URL(string: "https://github.com/drumandbytes/music-router")!)
    }
}

import AppKit
import ApplicationServices
import CoreGraphics
import ServiceManagement
import UniformTypeIdentifiers

final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var isEnabled = Config.isEnabled
    private var replacementItem: NSMenuItem?
    private var permissionsItem: NSMenuItem?
    private var inputMonitoringItem: NSMenuItem?
    private var accessibilityItem: NSMenuItem?
    private var toggleItem: NSMenuItem?
    private var resumeItem: NSMenuItem?
    private lazy var settings = SettingsWindowController(actions: SettingsActions(
        setEnabled: { [weak self] in self?.setEnabled($0) },
        setIconHidden: { [weak self] in self?.setIconHidden($0) },
        chooseApp: { [weak self] in self?.chooseReplacementApp() },
        chooseURL: { [weak self] in self?.chooseCustomURL() },
        resetPermissions: { [weak self] in self?.resetPermissions() },
        nowPlayingHealth: { [weak self] in self?.nowPlayingHealth() ?? .starting },
        cycleShortcutChanged: { [weak self] in self?.onCycleShortcutChanged?() ?? true },
        shortcutRecording: { [weak self] in self?.onShortcutRecording?($0) }
    ))
    var onToggle: ((Bool) -> Void)?
    var onCycleShortcutChanged: (() -> Bool)?
    var onShortcutRecording: ((Bool) -> Void)?
    private var targetItem: NSMenuItem?
    private var flashWork: DispatchWorkItem?
    var nowPlayingHealth: () -> NowPlayingObserver.Health = { .starting }

    override init() {
        super.init()
        statusItem.button?.image = NSImage(
            systemSymbolName: "music.quarternote.3",
            accessibilityDescription: "Music Router"
        )
        statusItem.menu = buildMenu()
        updateIcon()
        statusItem.isVisible = !Config.menuBarIconHidden
        // no icon means no other way in
        if Config.menuBarIconHidden { showSettings() }
    }

    func showSettings() {
        settings.show()
    }

    // appearsDisabled dims it natively, no "off" asset
    private func updateIcon() {
        statusItem.button?.appearsDisabled = !isEnabled
    }

    /// A hidden icon has no menu; the settings window (reopen the app) is the way back.
    private func setIconHidden(_ hidden: Bool) {
        Config.menuBarIconHidden = hidden
        statusItem.isVisible = !hidden
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
        self.toggleItem = toggleItem

        menu.addItem(.separator())

        // Submenu is filled in menuWillOpen, so it's always current.
        let replacementItem = NSMenuItem(title: "Replacement App", action: nil, keyEquivalent: "")
        replacementItem.submenu = NSMenu()
        menu.addItem(replacementItem)
        self.replacementItem = replacementItem

        // Submenu is filled in menuWillOpen (running players change).
        let targetItem = NSMenuItem(title: "Media Key Target", action: nil, keyEquivalent: "")
        targetItem.submenu = NSMenu()
        menu.addItem(targetItem)
        self.targetItem = targetItem

        let resumeItem = NSMenuItem(
            title: "Resume Last Player",
            action: #selector(toggleResumeLastPlayer),
            keyEquivalent: ""
        )
        resumeItem.target = self
        resumeItem.state = Config.resumeLastPlayer ? .on : .off
        menu.addItem(resumeItem)
        self.resumeItem = resumeItem

        let loginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let hideItem = NSMenuItem(
            title: "Hide Menu Bar Icon",
            action: #selector(hideMenuBarIcon),
            keyEquivalent: ""
        )
        hideItem.target = self
        menu.addItem(hideItem)

        let debugItem = NSMenuItem(
            title: "Debug Logging",
            action: #selector(toggleDebugLogging),
            keyEquivalent: ""
        )
        debugItem.target = self
        debugItem.state = Config.debugLogging ? .on : .off
        menu.addItem(debugItem)

        let revealLogItem = NSMenuItem(
            title: "Reveal Log in Finder",
            action: #selector(revealLog),
            keyEquivalent: ""
        )
        revealLogItem.target = self
        menu.addItem(revealLogItem)

        // Surfaces the easy-to-half-grant dual permission instead of silently
        // dead keys; each row shows its grant and opens its System Settings pane.
        menu.addItem(.separator())

        let inputMonitoringItem = NSMenuItem(title: "Input Monitoring", action: #selector(openInputMonitoringPane), keyEquivalent: "")
        inputMonitoringItem.target = self
        menu.addItem(inputMonitoringItem)
        self.inputMonitoringItem = inputMonitoringItem

        // macOS 27 renamed Accessibility to "Device Control and Data Access"
        let accessibilityItem = NSMenuItem(title: "Accessibility / Device Control", action: #selector(openAccessibilityPane), keyEquivalent: "")
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)
        self.accessibilityItem = accessibilityItem

        // Resetting when already granted is harmless.
        let permissionsItem = NSMenuItem(title: "Reset Permissions…", action: #selector(resetPermissions), keyEquivalent: "")
        permissionsItem.target = self
        permissionsItem.image = Self.symbol("lock.rotation")
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
        applyIcons(to: menu)
        return menu
    }

    private static func symbol(_ name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .regular))
    }

    /// Small leading icons, matched by item so each item's construction stays unchanged.
    private func applyIcons(to menu: NSMenu) {
        let icons: [String: String] = [
            "Enabled": "power",
            "Media Key Target": "scope",
            "Replacement App": "arrow.triangle.turn.up.right.circle",
            "Resume Last Player": "play.circle",
            "Launch at Login": "sunrise",
            "Settings…": "gearshape",
            "Hide Menu Bar Icon": "eye.slash",
            "Debug Logging": "ladybug",
            "Reveal Log in Finder": "doc.text.magnifyingglass",
            "About Music Router": "info.circle",
            "Help": "questionmark.circle",
            "Quit Music Router": "xmark.circle",
        ]
        for item in menu.items {
            if let name = icons[item.title] { item.image = Self.symbol(name) }
        }
    }

    private static func appIcon(path: String) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 16, height: 16)
        return icon
    }

    /// Refresh on open so grants and installs made while running show up.
    func menuWillOpen(_ menu: NSMenu) {
        toggleItem?.state = isEnabled ? .on : .off
        resumeItem?.state = Config.resumeLastPlayer ? .on : .off
        replacementItem?.submenu = buildReplacementMenu()
        targetItem?.submenu = buildTargetMenu()

        inputMonitoringItem?.image = Self.statusSymbol(granted: CGPreflightListenEventAccess())
        accessibilityItem?.image = Self.statusSymbol(granted: AXIsProcessTrusted())
    }

    private static func statusSymbol(granted: Bool) -> NSImage? {
        let name = granted ? "checkmark.circle.fill" : "xmark.circle.fill"
        let color: NSColor = granted ? .systemGreen : .systemRed
        return NSImage(systemSymbolName: name, accessibilityDescription: granted ? "Granted" : "Not granted")?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .regular).applying(.init(paletteColors: [.white, color])))
    }

    @objc private func openInputMonitoringPane() {
        openPrivacyPane("Privacy_ListenEvent")
    }

    @objc private func openAccessibilityPane() {
        openPrivacyPane("Privacy_Accessibility")
    }

    private func openPrivacyPane(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func buildTargetMenu() -> NSMenu {
        let submenu = NSMenu()
        let current = Config.targetApp

        let auto = NSMenuItem(title: "Automatic (Now Playing)", action: #selector(selectTarget(_:)), keyEquivalent: "")
        auto.target = self
        auto.image = Self.symbol("sparkles")
        auto.state = current == nil ? .on : .off
        submenu.addItem(auto)
        submenu.addItem(.separator())

        var ids = TargetApps.installed().map(\.bundleID)
        if let current, !ids.contains(current) { ids.append(current) }
        for id in ids {
            var title = TargetApps.name(for: id)
            if !TargetApps.isScriptable(id) { title += " (launch only)" }
            else if !TargetApps.isRunning(id) { title += " (not running)" }
            let item = NSMenuItem(title: title, action: #selector(selectTarget(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = id
            if let url = TargetApps.appURL(for: id) { item.image = Self.appIcon(path: url.path) }
            item.state = current == id ? .on : .off
            submenu.addItem(item)
        }

        submenu.addItem(.separator())
        let shortcut = NSMenuItem(title: "Cycle with \(Config.cycleShortcutBinding.display)", action: #selector(toggleCycleShortcut(_:)), keyEquivalent: "")
        shortcut.target = self
        shortcut.image = Self.symbol("keyboard")
        shortcut.state = Config.cycleShortcut ? .on : .off
        submenu.addItem(shortcut)

        let toast = NSMenuItem(title: "Show Message on Change", action: #selector(toggleTargetToast(_:)), keyEquivalent: "")
        toast.target = self
        toast.image = Self.symbol("bubble.left")
        toast.state = Config.showTargetToast ? .on : .off
        submenu.addItem(toast)
        return submenu
    }

    @objc private func selectTarget(_ sender: NSMenuItem) {
        Config.targetApp = sender.representedObject as? String
    }

    @objc private func toggleTargetToast(_ sender: NSMenuItem) {
        Config.showTargetToast.toggle()
    }

    @objc private func toggleCycleShortcut(_ sender: NSMenuItem) {
        Config.cycleShortcut.toggle()
        _ = onCycleShortcutChanged?()
    }

    /// Brief status-bar label so a shortcut change is visible without opening the menu.
    func flash(_ text: String) {
        flashWork?.cancel()
        statusItem.button?.title = " \(text)"
        let work = DispatchWorkItem { [weak self] in self?.statusItem.button?.title = "" }
        flashWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
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
        blockOnlyItem.image = Self.symbol("nosign")
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
            item.image = Config.isWebURL(app.target) ? Self.symbol("globe") : Self.appIcon(path: app.target)
            item.state = current == app.target ? .on : .off
            submenu.addItem(item)
        }

        // check against the filtered list, or an uninstalled selection shows nothing checked
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
        chooseItem.image = Self.symbol("folder")
        submenu.addItem(chooseItem)

        let customURLItem = NSMenuItem(
            title: "Custom URL…",
            action: #selector(chooseCustomURL),
            keyEquivalent: ""
        )
        customURLItem.target = self
        customURLItem.image = Self.symbol("link")
        submenu.addItem(customURLItem)

        return submenu
    }

    @objc private func openSettings() {
        showSettings()
    }

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        setEnabled(!isEnabled)
    }

    private func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        Config.isEnabled = enabled
        toggleItem?.state = enabled ? .on : .off
        updateIcon()
        onToggle?(enabled)
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        LoginItem.toggle()
        sender.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func toggleResumeLastPlayer(_ sender: NSMenuItem) {
        Config.resumeLastPlayer.toggle()
        sender.state = Config.resumeLastPlayer ? .on : .off
    }

    @objc private func toggleDebugLogging(_ sender: NSMenuItem) {
        Config.debugLogging.toggle()
        sender.state = Config.debugLogging ? .on : .off
        DebugLog.shared.log("debug logging on")
    }

    @objc private func revealLog() {
        DebugLog.shared.reveal()
    }

    @objc private func hideMenuBarIcon() {
        setIconHidden(true)
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

    /// Clears both TCC grants (they go stale when the signing identity changes)
    /// and `hasRequestedPermissions`, then relaunches so the OS re-evaluates.
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

        // -n: a new process; otherwise open reactivates us and we just quit
        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        relaunch.arguments = ["-n", Bundle.main.bundleURL.path]
        try? relaunch.run()
        NSApp.terminate(nil)
    }

    @objc private func showAbout() {
        // accessory apps don't auto-activate; else the panel opens behind
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func showHelp() {
        NSWorkspace.shared.open(URL(string: "https://github.com/drumandbytes/music-router")!)
    }
}

import AppKit
import ApplicationServices
import CoreGraphics
import UniformTypeIdentifiers

final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var isEnabled = Config.isEnabled
    private var replacementItem: NSMenuItem?
    private var inputMonitoringItem: NSMenuItem?
    private var accessibilityItem: NSMenuItem?
    private var toggleItem: NSMenuItem?
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

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

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

    private func applyIcons(to menu: NSMenu) {
        let icons: [String: String] = [
            "Enabled": "power",
            "Media Key Target": "scope",
            "Replacement App": "arrow.triangle.turn.up.right.circle",
            "Settings…": "gearshape",
            "About Music Router": "info.circle",
            "Help": "questionmark.circle",
            "Quit Music Router": "xmark.circle",
        ]
        for item in menu.items {
            if let name = icons[item.title] { item.setIcon(Self.symbol(name)) }
        }
    }

    /// Refresh on open so grants and installs made while running show up.
    func menuWillOpen(_ menu: NSMenu) {
        toggleItem?.state = isEnabled ? .on : .off
        replacementItem?.submenu = buildReplacementMenu()
        targetItem?.submenu = buildTargetMenu()

        inputMonitoringItem?.setIcon(Self.statusSymbol(granted: CGPreflightListenEventAccess()))
        accessibilityItem?.setIcon(Self.statusSymbol(granted: AXIsProcessTrusted()))
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
        auto.setIcon(Self.symbol("sparkles"))
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
            item.setIcon(TargetApps.icon(bundleID: id))
            item.state = current == id ? .on : .off
            submenu.addItem(item)
        }

        return submenu
    }

    @objc private func selectTarget(_ sender: NSMenuItem) {
        Config.targetApp = sender.representedObject as? String
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
        blockOnlyItem.setIcon(Self.symbol("nosign"))
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
            item.setIcon(Config.isWebURL(app.target) ? Self.symbol("globe") : TargetApps.icon(path: app.target))
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
        chooseItem.setIcon(Self.symbol("folder"))
        submenu.addItem(chooseItem)

        let customURLItem = NSMenuItem(
            title: "Custom URL…",
            action: #selector(chooseCustomURL),
            keyEquivalent: ""
        )
        customURLItem.target = self
        customURLItem.setIcon(Self.symbol("link"))
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
        let current = Config.replacement.flatMap { Config.isWebURL($0) ? $0 : nil } ?? ""
        let result = Dialog.run(DialogSpec(
            symbol: "link",
            color: .blue,
            title: "Custom Replacement URL",
            message: "Opened instead of Music.app, e.g. a web player not in the list.",
            primary: "Set",
            field: .init(placeholder: "https://example.com/player", initial: current, validate: Config.urlError)
        ))
        guard result.accepted else { return }
        Config.replacement = result.text
    }

    /// Clears both TCC grants (they go stale when the signing identity changes)
    /// and `hasRequestedPermissions`, then relaunches so the OS re-evaluates.
    @objc private func resetPermissions() {
        let confirmed = Dialog.run(DialogSpec(
            symbol: "lock.rotation",
            color: .red,
            title: "Reset Permissions?",
            message: "Clears the Input Monitoring and Accessibility / Device Control grants for Music Router and relaunches it so you can grant them again.",
            primary: "Reset",
            destructive: true
        )).accepted
        guard confirmed else { return }

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
        AboutWindowController.shared.show()
    }

    @objc private func showHelp() {
        NSWorkspace.shared.open(Links.help)
    }
}

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

    // appearsDisabled dims it natively, no "off" asset
    private func updateIcon() {
        statusItem.button?.appearsDisabled = !isEnabled
    }

    /// A hidden item has no menu to unhide from; relaunch is the only way back.
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

        // Surfaces the easy-to-half-grant dual permission instead of silently
        // dead keys. Resetting when already granted is harmless.
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

    /// Refresh on open so grants and installs made while running show up.
    func menuWillOpen(_ menu: NSMenu) {
        replacementItem?.submenu = buildReplacementMenu()

        let inputMonitoring = CGPreflightListenEventAccess() ? "✓" : "✗"
        let accessibility = AXIsProcessTrusted() ? "✓" : "✗"
        // macOS 27 renamed Accessibility to "Device Control and Data Access"; show both
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

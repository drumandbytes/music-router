import AppKit
import ServiceManagement
import UniformTypeIdentifiers

/// Menu bar icon: shows current state, lets you toggle blocking, pick a
/// replacement app, enable launch-at-login, hide the icon, and quit.
final class StatusBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var isEnabled = true
    var onToggle: ((Bool) -> Void)?

    init() {
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

        let replacementItem = NSMenuItem(title: "Replacement App", action: nil, keyEquivalent: "")
        replacementItem.submenu = buildReplacementMenu()
        menu.addItem(replacementItem)

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

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "Quit Music Router",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        return menu
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

        for app in Config.availablePredefinedApps {
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

        if let current, !Config.predefinedApps.contains(where: { $0.target == current }) {
            let label = Config.isWebURL(current) ? current : (current as NSString).lastPathComponent
            let currentItem = NSMenuItem(title: "Current: \(label)", action: nil, keyEquivalent: "")
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
        statusItem.menu = buildMenu()
    }

    @objc private func selectPredefinedApp(_ sender: NSMenuItem) {
        guard let target = sender.representedObject as? String else { return }
        Config.replacement = target
        statusItem.menu = buildMenu()
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
        statusItem.menu = buildMenu()
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
        guard Config.isWebURL(text) else { return }
        Config.replacement = text
        statusItem.menu = buildMenu()
    }
}

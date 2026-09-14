import AppKit
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
        // A fresh launch always means the user just started the app, so it's
        // the natural place to undo a previous "Hide Menu Bar Icon" — the
        // hidden icon itself has no way to offer this, so a relaunch has to.
        unhideIfNeeded()
    }

    /// Un-hides the icon if it was previously hidden — called on every
    /// (re)launch, since a hidden `NSStatusItem` has no menu of its own to
    /// undo the hide from.
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
        loginItem.state = LoginItem.isEnabled ? .on : .off
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
            let item = NSMenuItem(
                title: app.name,
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
        onToggle?(isEnabled)
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let newValue = !LoginItem.isEnabled
        LoginItem.setEnabled(newValue)
        sender.state = LoginItem.isEnabled ? .on : .off
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

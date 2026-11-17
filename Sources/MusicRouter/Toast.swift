import AppKit

/// Brief floating HUD for feedback that can't rely on the menu bar icon
/// (hidden, or the menu bar is replaced by a tool such as SketchyBar).
final class Toast {
    static let shared = Toast()

    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?

    static func targetMessage(name: String?) -> String {
        "Media keys → \(name ?? "Automatic")"
    }

    func show(_ text: String, duration: TimeInterval = 1.6) {
        hideWork?.cancel()
        let panel = self.panel ?? makePanel()
        self.panel = panel

        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .labelColor
        label.sizeToFit()

        let size = NSSize(width: label.frame.width + 56, height: label.frame.height + 32)
        let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        background.material = .hudWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 16
        background.layer?.masksToBounds = true
        label.frame.origin = NSPoint(x: 28, y: 16)
        background.addSubview(label)
        panel.contentView = background

        // screen under the pointer, since that's where the user is looking
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        if let area = screen?.visibleFrame {
            panel.setFrame(NSRect(
                x: area.midX - size.width / 2,
                y: area.minY + 120,
                width: size.width,
                height: size.height
            ), display: true)
        }
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        let work = DispatchWorkItem { [weak panel] in
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.25; panel?.animator().alphaValue = 0 },
                                                 completionHandler: { panel?.orderOut(nil) })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        return panel
    }
}

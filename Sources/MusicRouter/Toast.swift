import AppKit

/// Brief floating HUD for feedback that can't rely on the menu bar icon
/// (hidden, or the menu bar is replaced by a tool such as SketchyBar).
/// Liquid Glass on macOS 26+, a blur material before that.
final class Toast {
    static let shared = Toast()

    struct Content: Equatable {
        let title: String
        let subtitle: String
        let bundleID: String?
    }

    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?

    /// `bundleID == nil` = Automatic.
    static func targetContent(bundleID: String?) -> Content {
        Content(
            title: bundleID.map(TargetApps.name(for:)) ?? "Automatic",
            subtitle: "Media keys",
            bundleID: bundleID
        )
    }

    func show(_ content: Content, duration: TimeInterval = 1.6) {
        hideWork?.cancel()
        let panel = self.panel ?? makePanel()
        self.panel = panel

        let body = makeBody(content)
        let size = body.fittingSize
        body.frame = NSRect(origin: .zero, size: size)
        panel.contentView = wrapInGlass(body, size: size)

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

    private func makeBody(_ content: Content) -> NSView {
        let icon = NSImageView()
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.image = Self.icon(for: content.bundleID)
        icon.contentTintColor = content.bundleID == nil ? .labelColor : nil
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 44),
            icon.heightAnchor.constraint(equalToConstant: 44),
        ])

        let subtitle = NSTextField(labelWithString: content.subtitle.uppercased())
        subtitle.font = .systemFont(ofSize: 10, weight: .semibold)
        subtitle.textColor = .secondaryLabelColor
        let title = NSTextField(labelWithString: content.title)
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        title.textColor = .labelColor

        let text = NSStackView(views: [subtitle, title])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 1

        let row = NSStackView(views: [icon, text])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 14
        row.edgeInsets = NSEdgeInsets(top: 14, left: 18, bottom: 14, right: 26)
        return row
    }

    private static func icon(for bundleID: String?) -> NSImage? {
        if let bundleID, let url = TargetApps.appURL(for: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        let config = NSImage.SymbolConfiguration(pointSize: 30, weight: .regular)
        return NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Automatic")?
            .withSymbolConfiguration(config)
    }

    private func wrapInGlass(_ body: NSView, size: NSSize) -> NSView {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView(frame: NSRect(origin: .zero, size: size))
            glass.contentView = body
            glass.cornerRadius = size.height / 2
            return glass
        }
        #endif
        let blur = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        blur.material = .hudWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = size.height / 2
        blur.layer?.masksToBounds = true
        blur.addSubview(body)
        return blur
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.title = "Music Router"
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        return panel
    }
}

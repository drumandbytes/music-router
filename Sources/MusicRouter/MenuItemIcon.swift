import AppKit

extension NSMenuItem {
    /// Sets the item's icon and keeps it visible. From macOS 27 AppKit hides
    /// menu item images by default (NSMenuItem.preferredImageVisibility,
    /// `.visible` = 1), even for apps that set `image` themselves. The property
    /// only exists in the 27 SDK, which CI doesn't build with, so it's set
    /// through KVC and only where the running system has it.
    func setIcon(_ icon: NSImage?) {
        image = icon
        guard icon != nil, responds(to: NSSelectorFromString("setPreferredImageVisibility:")) else { return }
        setValue(1, forKey: "preferredImageVisibility")
    }

    /// `nil` where the OS predates the property; otherwise its raw value
    /// (0 automatic, 1 visible, 2 hidden).
    var iconVisibilityRawValue: Int? {
        responds(to: NSSelectorFromString("preferredImageVisibility"))
            ? value(forKey: "preferredImageVisibility") as? Int
            : nil
    }
}

import AppKit

extension NSMenuItem {
    /// From macOS 27 AppKit hides menu item images unless `preferredImageVisibility`
    /// is `.visible` (1). The property is only in the 27 SDK, which CI doesn't
    /// build with, so it's set via KVC where the running system has it.
    func setIcon(_ icon: NSImage?) {
        image = icon
        guard icon != nil, responds(to: NSSelectorFromString("setPreferredImageVisibility:")) else { return }
        setValue(1, forKey: "preferredImageVisibility")
    }
}

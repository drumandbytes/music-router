import AppKit
import Carbon.HIToolbox

/// A global shortcut: Carbon key code + Carbon modifier mask (what
/// `RegisterEventHotKey` takes) and the key's label for display.
struct Shortcut: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var key: String

    static let defaultCycle = Shortcut(
        keyCode: UInt32(kVK_ANSI_M),
        modifiers: UInt32(cmdKey | optionKey | controlKey),
        key: "M"
    )

    /// Needs ⌘, ⌥ or ⌃: a bare key or ⇧+key would steal normal typing everywhere.
    var isValid: Bool {
        modifiers & UInt32(cmdKey | optionKey | controlKey) != 0
    }

    var display: String {
        var symbols = ""
        if modifiers & UInt32(controlKey) != 0 { symbols += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { symbols += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { symbols += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { symbols += "⌘" }
        return symbols + key
    }

    static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var mask: UInt32 = 0
        if flags.contains(.command) { mask |= UInt32(cmdKey) }
        if flags.contains(.option) { mask |= UInt32(optionKey) }
        if flags.contains(.control) { mask |= UInt32(controlKey) }
        if flags.contains(.shift) { mask |= UInt32(shiftKey) }
        return mask
    }

    private static let specialKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    static func label(keyCode: Int, characters: String?) -> String {
        if let special = specialKeys[keyCode] { return special }
        if let characters, let first = characters.unicodeScalars.first,
           !CharacterSet.controlCharacters.contains(first) {
            return characters.uppercased()
        }
        return "Key \(keyCode)"
    }

    /// `nil` unless the event forms a valid shortcut.
    init?(event: NSEvent) {
        let candidate = Shortcut(
            keyCode: UInt32(event.keyCode),
            modifiers: Self.carbonModifiers(event.modifierFlags),
            key: Self.label(keyCode: Int(event.keyCode), characters: event.charactersIgnoringModifiers)
        )
        guard candidate.isValid else { return nil }
        self = candidate
    }

    init(keyCode: UInt32, modifiers: UInt32, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.key = key
    }
}

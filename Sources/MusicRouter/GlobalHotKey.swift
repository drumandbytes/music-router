import Carbon.HIToolbox

/// One global shortcut via `RegisterEventHotKey` (public API; needs no
/// Accessibility or Input Monitoring grant, unlike an event tap). Only one is
/// ever registered, so the handler is a single static closure.
final class GlobalHotKey {
    private static var action: (() -> Void)?
    private static var handlerInstalled = false

    private var ref: EventHotKeyRef?

    /// `modifiers` are Carbon masks (`cmdKey | optionKey | controlKey`).
    init?(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        Self.installHandlerIfNeeded()
        let hotKeyID = EventHotKeyID(signature: OSType(0x4D52_4B59), id: 1) // 'MRKY'
        guard RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref) == noErr
        else { return nil }
        Self.action = action
    }

    func unregister() {
        guard let ref else { return }
        UnregisterEventHotKey(ref)
        self.ref = nil
        Self.action = nil
    }

    deinit { unregister() }

    private static func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            GlobalHotKey.action?()
            return noErr
        }, 1, &spec, nil, nil)
    }
}

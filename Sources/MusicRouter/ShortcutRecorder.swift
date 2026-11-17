import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Click, press a combination, done. Esc or clicking away cancels.
final class ShortcutRecorderButton: NSButton {
    var onCapture: ((Shortcut) -> Void)?
    var onRecordingChange: ((Bool) -> Void)?

    var shortcut = Shortcut.defaultCycle { didSet { refreshTitle() } }
    private(set) var isRecording = false

    override var acceptsFirstResponder: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        bezelStyle = .rounded
        target = self
        action = #selector(toggleRecording)
        refreshTitle()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func refreshTitle() {
        title = isRecording ? "Press shortcut…" : shortcut.display
    }

    @objc private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        window?.makeFirstResponder(self)
        isRecording = true
        refreshTitle()
        onRecordingChange?(true)
    }

    private func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        refreshTitle()
        onRecordingChange?(false)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { return super.keyDown(with: event) }
        if Int(event.keyCode) == kVK_Escape { return stopRecording() }
        if let captured = Shortcut(event: event) {
            shortcut = captured
            onCapture?(captured)
            stopRecording()
        } else {
            NSSound.beep() // needs ⌘, ⌥ or ⌃
        }
    }

    // ⌘-combos arrive here before keyDown
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event)
        return true
    }

    override func resignFirstResponder() -> Bool {
        stopRecording()
        return super.resignFirstResponder()
    }
}

struct ShortcutRecorder: NSViewRepresentable {
    let shortcut: Shortcut
    let onCapture: (Shortcut) -> Void
    let onRecordingChange: (Bool) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton(frame: .zero)
        button.shortcut = shortcut
        button.onCapture = onCapture
        button.onRecordingChange = onRecordingChange
        return button
    }

    func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
        if !button.isRecording { button.shortcut = shortcut }
        button.onCapture = onCapture
        button.onRecordingChange = onRecordingChange
    }
}

import AppKit
import SwiftUI

/// A confirmation or one-field prompt in the app's glass style, replacing
/// stock `NSAlert`s. Modal; Return confirms, Esc cancels.
struct DialogSpec {
    struct Field {
        var placeholder: String
        var initial: String = ""
        /// Inline error, or `nil` if acceptable.
        var validate: (String) -> String?
    }

    var symbol: String
    var color: Color
    var title: String
    var message: String
    var primary: String
    var secondary = "Cancel"
    var destructive = false
    var field: Field?
}

struct DialogResult {
    var accepted: Bool
    var text: String
}

private struct DialogView: View {
    let spec: DialogSpec
    let finish: (DialogResult) -> Void

    @State private var text: String
    @State private var error: String?
    @FocusState private var focused: Bool

    init(spec: DialogSpec, finish: @escaping (DialogResult) -> Void) {
        self.spec = spec
        self.finish = finish
        _text = State(initialValue: spec.field?.initial ?? "")
    }

    var body: some View {
        VStack(spacing: 14) {
            IconTile(symbol: spec.symbol, color: spec.color, size: 56)
            Text(spec.title)
                .font(.title3.bold())
            Text(spec.message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let field = spec.field {
                TextField(field.placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .onSubmit(confirm)
                    .onChange(of: text) { _ in error = nil }
                if let error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button(spec.secondary) { finish(DialogResult(accepted: false, text: text)) }
                    .keyboardShortcut(.cancelAction)
                Button(spec.primary, action: confirm)
                    .keyboardShortcut(.defaultAction)
                    .tint(spec.destructive ? .red : .accentColor)
            }
            .controlSize(.large)
            .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 360)
        .environment(\.systemIconStyle, .current)
        .windowGlass()
        .onAppear { focused = spec.field != nil }
    }

    private func confirm() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let field = spec.field, let message = field.validate(trimmed) {
            error = message
            return
        }
        finish(DialogResult(accepted: true, text: trimmed))
    }
}

enum Dialog {
    @discardableResult
    static func run(_ spec: DialogSpec) -> DialogResult {
        // accessory app: activate or the dialog opens behind
        NSApp.activate(ignoringOtherApps: true)

        var result = DialogResult(accepted: false, text: "")
        var window: NSWindow?
        let hosting = NSHostingController(rootView: DialogView(spec: spec) { outcome in
            result = outcome
            NSApp.stopModal()
            window?.orderOut(nil)
        })
        let panel = NSWindow(contentViewController: hosting)
        panel.title = spec.title // hidden visually, but shown in window lists
        panel.styleMask = [.titled]
        panel.applyGlassChrome(hideTitle: true)
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isReleasedWhenClosed = false
        panel.center()
        window = panel

        NSApp.runModal(for: panel)
        return result
    }
}

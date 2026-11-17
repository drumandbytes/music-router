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
    /// Windows kept alive until their dialog finishes.
    private static var open: [NSWindow] = []

    /// Not modal on purpose: `runModal` opened from a SwiftUI button action (the
    /// Settings window) left the dialog's own buttons dead. With a `parent` it
    /// slides in as a sheet on that window; otherwise it's a floating window.
    static func present(
        _ spec: DialogSpec,
        relativeTo parent: NSWindow? = nil,
        completion: @escaping (DialogResult) -> Void
    ) {
        // accessory app: activate or the dialog opens behind
        NSApp.activate(ignoringOtherApps: true)

        var window: NSWindow?
        let hosting = NSHostingController(rootView: DialogView(spec: spec) { outcome in
            guard let window else { return }
            if let parent, window.sheetParent === parent { parent.endSheet(window) }
            window.orderOut(nil)
            open.removeAll { $0 === window }
            completion(outcome)
        })
        let panel = NSWindow(contentViewController: hosting)
        panel.title = spec.title // hidden visually, but shown in window lists
        panel.styleMask = [.titled]
        panel.applyGlassChrome(hideTitle: true)
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isReleasedWhenClosed = false
        window = panel
        open.append(panel)

        if let parent {
            parent.beginSheet(panel)
        } else {
            panel.level = .floating
            panel.center()
            panel.makeKeyAndOrderFront(nil)
        }
    }
}

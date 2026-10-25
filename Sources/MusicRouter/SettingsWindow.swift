import AppKit
import ApplicationServices
import CoreGraphics
import ServiceManagement
import SwiftUI

/// Mirrors the menu so the app stays configurable with the menu bar icon hidden.
/// Reads `Config` on every show; the menu and window both write straight to it.
final class SettingsModel: ObservableObject {
    @Published var isEnabled = Config.isEnabled
    @Published var replacement = Config.replacement
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published var showMenuBarIcon = !Config.menuBarIconHidden
    @Published var debugLogging = Config.debugLogging
    @Published var inputMonitoring = CGPreflightListenEventAccess()
    @Published var accessibility = AXIsProcessTrusted()

    func refresh() {
        isEnabled = Config.isEnabled
        replacement = Config.replacement
        launchAtLogin = SMAppService.mainApp.status == .enabled
        showMenuBarIcon = !Config.menuBarIconHidden
        debugLogging = Config.debugLogging
        inputMonitoring = CGPreflightListenEventAccess()
        accessibility = AXIsProcessTrusted()
    }
}

struct SettingsActions {
    var setEnabled: (Bool) -> Void
    var setIconHidden: (Bool) -> Void
    var chooseApp: () -> Void
    var chooseURL: () -> Void
    var resetPermissions: () -> Void
}

private struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    let actions: SettingsActions

    private static let blockOnly = "__block_only__"

    var body: some View {
        Form {
            Toggle("Enabled", isOn: Binding(
                get: { model.isEnabled },
                set: { model.isEnabled = $0; actions.setEnabled($0) }
            ))

            Picker("Replacement app", selection: Binding(
                get: { model.replacement ?? Self.blockOnly },
                set: {
                    Config.replacement = $0 == Self.blockOnly ? nil : $0
                    model.replacement = Config.replacement
                }
            )) {
                Text("Block only (no redirect)").tag(Self.blockOnly)
                ForEach(Config.availablePredefinedApps, id: \.target) { app in
                    Text(Config.isWebURL(app.target) ? "\(app.name) (Web)" : app.name).tag(app.target)
                }
                if let current = model.replacement,
                   !Config.availablePredefinedApps.contains(where: { $0.target == current }) {
                    let label = Config.isWebURL(current) ? current : (current as NSString).lastPathComponent
                    Text("\(label)\(Config.replacementIsMissing ? " (not found)" : "")").tag(current)
                }
            }
            HStack {
                Button("Choose App…") { actions.chooseApp(); model.refresh() }
                Button("Custom URL…") { actions.chooseURL(); model.refresh() }
            }

            Divider()

            Toggle("Launch at login", isOn: Binding(
                get: { model.launchAtLogin },
                set: { _ in
                    LoginItem.toggle()
                    model.launchAtLogin = SMAppService.mainApp.status == .enabled
                }
            ))
            Toggle("Show menu bar icon", isOn: Binding(
                get: { model.showMenuBarIcon },
                set: { model.showMenuBarIcon = $0; actions.setIconHidden(!$0) }
            ))
            Toggle("Debug logging", isOn: Binding(
                get: { model.debugLogging },
                set: {
                    Config.debugLogging = $0
                    model.debugLogging = $0
                    if $0 { DebugLog.shared.log("debug logging on") }
                }
            ))
            Button("Reveal Log in Finder") { DebugLog.shared.reveal() }

            Divider()

            LabeledContent("Input Monitoring", value: model.inputMonitoring ? "Granted" : "Not granted")
            // macOS 27 renamed Accessibility to "Device Control and Data Access"
            LabeledContent("Accessibility / Device Control", value: model.accessibility ? "Granted" : "Not granted")
            Button("Reset Permissions…") { actions.resetPermissions() }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }
}

enum LoginItem {
    static func toggle() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("MusicRouter: failed to toggle login item: \(error)")
        }
    }
}

final class SettingsWindowController: NSWindowController {
    let model = SettingsModel()

    init(actions: SettingsActions) {
        let hosting = NSHostingController(rootView: SettingsView(model: model, actions: actions))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Music Router Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func show() {
        model.refresh()
        // accessory app: activate or the window opens behind
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

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
    @Published var resumeLastPlayer = Config.resumeLastPlayer
    @Published var inputMonitoring = CGPreflightListenEventAccess()
    @Published var accessibility = AXIsProcessTrusted()
    @Published var nowPlayingHealth = NowPlayingObserver.Health.starting
    private var healthProvider: () -> NowPlayingObserver.Health = { .starting }
    private var healthObserver: NSObjectProtocol?

    func bindNowPlayingHealth(_ provider: @escaping () -> NowPlayingObserver.Health) {
        healthProvider = provider
        nowPlayingHealth = provider()
        healthObserver = NotificationCenter.default.addObserver(
            forName: NowPlayingObserver.healthChangedNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.nowPlayingHealth = self.healthProvider()
        }
    }

    func refresh() {
        nowPlayingHealth = healthProvider()
        isEnabled = Config.isEnabled
        replacement = Config.replacement
        launchAtLogin = SMAppService.mainApp.status == .enabled
        showMenuBarIcon = !Config.menuBarIconHidden
        debugLogging = Config.debugLogging
        resumeLastPlayer = Config.resumeLastPlayer
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
    var nowPlayingHealth: () -> NowPlayingObserver.Health
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    let actions: SettingsActions

    private static let blockOnly = "__block_only__"

    var body: some View {
        Form {
            Section {
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
            Toggle("Resume last player", isOn: Binding(
                get: { model.resumeLastPlayer },
                set: { Config.resumeLastPlayer = $0; model.resumeLastPlayer = $0 }
            ))
            .help("With nothing playing, the play key resumes the app that played last (if it's still running and scriptable) instead of launching the replacement.")
            HStack {
                Button("Choose App…") { actions.chooseApp(); model.refresh() }
                Button("Custom URL…") { actions.chooseURL(); model.refresh() }
            }

            }

            Section {
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

            }

            Section {
                LabeledContent("Input Monitoring", value: model.inputMonitoring ? "Granted" : "Not granted")
                // macOS 27 renamed Accessibility to "Device Control and Data Access"
                LabeledContent("Accessibility / Device Control", value: model.accessibility ? "Granted" : "Not granted")
                Button("Reset Permissions…") { actions.resetPermissions() }
            }

            Section {
                LabeledContent("Now Playing detection", value: Self.statusText(model.nowPlayingHealth, enabled: model.isEnabled))
            } footer: {
                if case .failed = model.nowPlayingHealth, model.isEnabled {
                    Text("Using a basic check (is any audio playing?) instead. Music is still blocked and keys still routed, but a paused player is no longer detected.")
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }
}

extension SettingsView {
    static func statusText(_ health: NowPlayingObserver.Health, enabled: Bool) -> String {
        guard enabled else { return "Off" }
        switch health {
        case .starting: return "Starting…"
        case .ok: return "Working"
        case .failed(let reason): return "Unavailable: \(reason)"
        }
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
        model.bindNowPlayingHealth(actions.nowPlayingHealth)
        let hosting = NSHostingController(rootView: SettingsView(model: model, actions: actions))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Music Router Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func show() {
        model.refresh()
        // accessory app: activate or the window opens behind
        NSApp.activate(ignoringOtherApps: true)
        // center() runs before the hosted content has sized the window and can push the
        // top under the menu bar; place it by hand inside the visible area instead
        if let window, let area = (window.screen ?? NSScreen.main)?.visibleFrame {
            window.layoutIfNeeded()
            let size = window.frame.size
            window.setFrameOrigin(NSPoint(
                x: area.midX - size.width / 2,
                y: max(area.minY, area.midY - size.height / 2)
            ))
        }
        window?.makeKeyAndOrderFront(nil)
    }
}

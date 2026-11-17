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
    @Published var targetApp = Config.targetApp
    @Published var cycleShortcut = Config.cycleShortcut
    @Published var cycleBinding = Config.cycleShortcutBinding
    @Published var shortcutError: String?
    @Published var showTargetToast = Config.showTargetToast
    @Published var iconStyle = SystemIconStyle.current
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
        targetApp = Config.targetApp
        cycleShortcut = Config.cycleShortcut
        cycleBinding = Config.cycleShortcutBinding
        showTargetToast = Config.showTargetToast
        iconStyle = SystemIconStyle.current
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
    /// Re-registers the hotkey; `false` if that failed.
    var cycleShortcutChanged: () -> Bool
    var shortcutRecording: (Bool) -> Void
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    let actions: SettingsActions

    private static let blockOnly = "__block_only__"
    private static let automatic = "__automatic__"

    private var targetChoices: [String] {
        var ids = TargetApps.installed().map(\.bundleID)
        if let current = model.targetApp, !ids.contains(current) { ids.append(current) }
        return ids
    }

    private func applyShortcut() {
        let ok = actions.cycleShortcutChanged()
        model.shortcutError = ok ? nil : "That shortcut is taken by another app. Pick a different one."
    }

    static func targetLabel(_ id: String) -> String {
        let name = TargetApps.name(for: id)
        return TargetApps.isScriptable(id) ? name : "\(name) (launch only)"
    }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { model.isEnabled },
                    set: { model.isEnabled = $0; actions.setEnabled($0) }
                )) { Tile("Enabled", "power", .green) }

                Picker(selection: Binding(
                    get: { model.replacement ?? Self.blockOnly },
                    set: {
                        Config.replacement = $0 == Self.blockOnly ? nil : $0
                        model.replacement = Config.replacement
                    }
                )) {
                    Label("Block only (no redirect)", systemImage: "nosign").tag(Self.blockOnly)
                    ForEach(Config.availablePredefinedApps, id: \.target) { app in
                        appLabel(Config.isWebURL(app.target) ? "\(app.name) (Web)" : app.name, target: app.target)
                            .tag(app.target)
                    }
                    if let current = model.replacement,
                       !Config.availablePredefinedApps.contains(where: { $0.target == current }) {
                        let label = Config.isWebURL(current) ? current : (current as NSString).lastPathComponent
                        appLabel("\(label)\(Config.replacementIsMissing ? " (not found)" : "")", target: current)
                            .tag(current)
                    }
                } label: { Tile("Replacement app", "arrow.triangle.turn.up.right.circle", .blue) }

                HStack {
                    Button("Choose App…") { actions.chooseApp(); model.refresh() }
                    Button("Custom URL…") { actions.chooseURL(); model.refresh() }
                }

                Toggle(isOn: Binding(
                    get: { model.resumeLastPlayer },
                    set: { Config.resumeLastPlayer = $0; model.resumeLastPlayer = $0 }
                )) { Tile("Resume last player", "play.circle", .orange) }
                .help("With nothing playing, the play key resumes the app that played last (if it's still running and scriptable) instead of launching the replacement.")
            } header: { Text("Routing") }

            Section {
                Picker(selection: Binding(
                    get: { model.targetApp ?? Self.automatic },
                    set: {
                        Config.targetApp = $0 == Self.automatic ? nil : $0
                        model.targetApp = Config.targetApp
                    }
                )) {
                    Label("Automatic (Now Playing)", systemImage: "sparkles").tag(Self.automatic)
                    ForEach(targetChoices, id: \.self) { id in
                        Label {
                            Text(Self.targetLabel(id))
                        } icon: {
                            Image(nsImage: TargetApps.icon(bundleID: id))
                        }
                        .tag(id)
                    }
                } label: { Tile("Media key target", "scope", .pink) }

                Toggle(isOn: Binding(
                    get: { model.cycleShortcut },
                    set: {
                        Config.cycleShortcut = $0
                        model.cycleShortcut = $0
                        applyShortcut()
                    }
                )) { Tile("Cycle with a shortcut", "keyboard", .purple) }

                if model.cycleShortcut {
                    LabeledContent {
                        HStack {
                            ShortcutRecorder(
                                shortcut: model.cycleBinding,
                                onCapture: {
                                    Config.cycleShortcutBinding = $0
                                    model.cycleBinding = Config.cycleShortcutBinding
                                    applyShortcut()
                                },
                                onRecordingChange: { actions.shortcutRecording($0) }
                            )
                            .frame(width: 130)
                            Button("Reset") {
                                Config.cycleShortcutBinding = .defaultCycle
                                model.cycleBinding = .defaultCycle
                                applyShortcut()
                            }
                            .disabled(model.cycleBinding == .defaultCycle)
                        }
                    } label: { Tile("Shortcut", "command", .gray) }

                    Toggle(isOn: Binding(
                        get: { model.showTargetToast },
                        set: { Config.showTargetToast = $0; model.showTargetToast = $0 }
                    )) { Tile("Show a message on change", "bubble.left", .teal) }

                    if let error = model.shortcutError {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                }
            } header: { Text("Media key target") }

            Section {
                Toggle(isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { _ in
                        LoginItem.toggle()
                        model.launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                )) { Tile("Launch at login", "sunrise", .orange) }
                Toggle(isOn: Binding(
                    get: { model.showMenuBarIcon },
                    set: { model.showMenuBarIcon = $0; actions.setIconHidden(!$0) }
                )) { Tile("Show menu bar icon", "menubar.rectangle", .indigo) }
                Toggle(isOn: Binding(
                    get: { model.debugLogging },
                    set: {
                        Config.debugLogging = $0
                        model.debugLogging = $0
                        if $0 { DebugLog.shared.log("debug logging on") }
                    }
                )) { Tile("Debug logging", "ladybug", .brown) }
                Button { DebugLog.shared.reveal() } label: {
                    Label("Reveal Log in Finder", systemImage: "doc.text.magnifyingglass")
                }
            } header: { Text("General") }

            Section {
                LabeledContent {
                    status(model.inputMonitoring ? "Granted" : "Not granted", ok: model.inputMonitoring)
                } label: { Tile("Input Monitoring", "keyboard.badge.eye", .blue) }
                // macOS 27 renamed Accessibility to "Device Control and Data Access"
                LabeledContent {
                    status(model.accessibility ? "Granted" : "Not granted", ok: model.accessibility)
                } label: { Tile("Accessibility / Device Control", "accessibility", .blue) }
                Button { actions.resetPermissions() } label: {
                    Label("Reset Permissions…", systemImage: "lock.rotation")
                }
            } header: { Text("Permissions") }

            Section {
                LabeledContent {
                    detectionStatus
                } label: { Tile("Now Playing detection", "waveform", .green) }
            } footer: {
                if case .failed = model.nowPlayingHealth, model.isEnabled {
                    Text("Using a basic check (is any audio playing?) instead. Music is still blocked and keys still routed, but a paused player is no longer detected.")
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .environment(\.systemIconStyle, model.iconStyle)
        .windowGlass()
    }

    private func status(_ text: String, ok: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok ? .green : .red)
            Text(text).foregroundStyle(.secondary)
        }
    }

    private var detectionStatus: some View {
        let text = Self.statusText(model.nowPlayingHealth, enabled: model.isEnabled)
        let color: Color
        switch (model.isEnabled, model.nowPlayingHealth) {
        case (false, _): color = .gray
        case (_, .ok): color = .green
        case (_, .starting): color = .yellow
        case (_, .failed): color = .red
        }
        return HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func appLabel(_ title: String, target: String) -> some View {
        if Config.isWebURL(target) {
            Label(title, systemImage: "globe")
        } else {
            Label {
                Text(title)
            } icon: {
                Image(nsImage: TargetApps.icon(path: target))
            }
        }
    }
}

/// Row label: an `IconTile` plus the title, in the style of System Settings.
private struct Tile: View {
    let title: String
    let symbol: String
    let color: Color

    init(_ title: String, _ symbol: String, _ color: Color) {
        self.title = title
        self.symbol = symbol
        self.color = color
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            IconTile(symbol: symbol, color: color, size: 24)
        }
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
        window.applyGlassChrome()
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

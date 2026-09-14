import ServiceManagement

/// Launch-at-login, via the modern SMAppService API (macOS 13+) — no manual
/// System Settings > Login Items step required.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("MusicRouter: failed to \(enabled ? "register" : "unregister") login item: \(error)")
        }
    }
}

import SwiftUI

/// The macOS 26 "Icon & widget style" choice (Default / Dark / Clear / Tinted),
/// read from the global `AppleIconAppearanceTheme` default, so in-app icon
/// tiles can match the Dock.
struct SystemIconStyle: Equatable {
    enum Kind: Equatable { case regular, clear, tinted }

    var kind: Kind
    /// `nil` = follow the light/dark appearance ("…Automatic").
    var forcedDark: Bool?

    static let `default` = SystemIconStyle(kind: .regular, forcedDark: nil)

    /// Values look like `RegularAutomatic`, `ClearDark`, `TintedLight`.
    static func parse(_ theme: String?) -> SystemIconStyle {
        guard let theme else { return .default }
        let kind: Kind
        if theme.hasPrefix("Clear") { kind = .clear }
        else if theme.hasPrefix("Tinted") { kind = .tinted }
        else { kind = .regular }
        let forced: Bool?
        if theme.hasSuffix("Dark") { forced = true }
        else if theme.hasSuffix("Light") { forced = false }
        else { forced = nil }
        return SystemIconStyle(kind: kind, forcedDark: forced)
    }

    static var current: SystemIconStyle {
        parse(UserDefaults.standard.string(forKey: "AppleIconAppearanceTheme"))
    }

    func isDark(colorScheme: ColorScheme) -> Bool {
        forcedDark ?? (colorScheme == .dark)
    }
}

private struct SystemIconStyleKey: EnvironmentKey {
    static let defaultValue = SystemIconStyle.default
}

extension EnvironmentValues {
    var systemIconStyle: SystemIconStyle {
        get { self[SystemIconStyleKey.self] }
        set { self[SystemIconStyleKey.self] = newValue }
    }
}

import SwiftUI

/// Rounded icon tile that follows the system icon style: colour, dark, clear
/// glass or tinted (see `SystemIconStyle`).
struct IconTile: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 24

    @Environment(\.systemIconStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    private var dark: Bool { style.isDark(colorScheme: colorScheme) }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: size * 0.25, style: .continuous) }

    /// Tinted style uses one colour (the accent) for every tile.
    private var tint: Color { style.kind == .tinted ? .accentColor : color }

    var body: some View {
        let base = Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .frame(width: size, height: size)
        Group {
            switch (style.kind, dark) {
            case (.regular, false), (.tinted, false):
                base.foregroundStyle(.white).background(tint.gradient, in: shape)
            case (.regular, true), (.tinted, true):
                base.foregroundStyle(tint).background(Color(white: 0.16).gradient, in: shape)
            case (.clear, _):
                clearTile(base)
            }
        }
    }

    @ViewBuilder
    private func clearTile(_ base: some View) -> some View {
        let glyphColor: Color = dark ? .white : color
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            base.foregroundStyle(glyphColor).glassEffect(.regular.tint(color.opacity(0.18)), in: shape)
        } else {
            base.foregroundStyle(glyphColor).background(.ultraThinMaterial, in: shape)
        }
        #else
        base.foregroundStyle(glyphColor).background(.ultraThinMaterial, in: shape)
        #endif
    }
}

extension View {
    /// Material window background where the OS supports it.
    @ViewBuilder
    func windowGlass() -> some View {
        if #available(macOS 15.0, *) {
            containerBackground(.regularMaterial, for: .window)
        } else {
            self
        }
    }
}

/// Window chrome shared by Settings, dialogs and About: transparent title
/// bar over the content, draggable by its background.
extension NSWindow {
    func applyGlassChrome(hideTitle: Bool = false) {
        styleMask.insert(.fullSizeContentView)
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        if hideTitle { titleVisibility = .hidden }
    }
}

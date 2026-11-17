import AppKit
import SwiftUI

struct AboutView: View {
    static func versionText(short: String?, build: String?) -> String {
        guard let short, !short.isEmpty else { return "Development build" }
        if let build, !build.isEmpty, build != short { return "Version \(short) (\(build))" }
        return "Version \(short)"
    }

    private let version = AboutView.versionText(
        short: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
        build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    )

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            VStack(spacing: 2) {
                Text("Music Router").font(.title.bold())
                Text(version).foregroundStyle(.secondary)
            }
            Text("Stops Music.app from launching and routes your media keys to the app that should get them.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                row("questionmark.circle", "Help & Troubleshooting", Links.help, .blue)
                row("chevron.left.forwardslash.chevron.right", "Source on GitHub", Links.repo, .gray)
                row("square.grid.2x2", "Part of Drumandbytes", Links.projects, .orange)
            }
            .padding(.top, 6)

            VStack(spacing: 2) {
                Text("MIT License · © drumandbytes")
                HStack(spacing: 4) {
                    Text("Uses mediaremote-adapter,")
                    Link("BSD 3-Clause", destination: Links.adapterLicense)
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        }
        .padding(28)
        .frame(width: 340)
        .environment(\.systemIconStyle, .current)
        .windowGlass()
    }

    private func row(_ symbol: String, _ title: String, _ url: URL, _ color: Color) -> some View {
        Link(destination: url) {
            Label {
                Text(title)
            } icon: {
                IconTile(symbol: symbol, color: color, size: 24)
            }
        }
        .buttonStyle(.plain)
    }
}

final class AboutWindowController: NSWindowController {
    static let shared = AboutWindowController()

    private init() {
        let window = NSWindow(contentViewController: NSHostingController(rootView: AboutView()))
        window.title = "About Music Router" // hidden visually, but shown in window lists
        window.styleMask = [.titled, .closable]
        window.applyGlassChrome(hideTitle: true)
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func show() {
        // accessory app: activate or the window opens behind
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}

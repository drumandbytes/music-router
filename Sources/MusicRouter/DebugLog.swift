import Foundation

/// Opt-in diagnostics (`Config.debugLogging`, off by default) written to
/// ~/Library/Logs/MusicRouter.log. Only media-key names, bundle IDs and state
/// changes go in here, never titles, artists or other keys.
final class DebugLog {
    static let shared = DebugLog(
        url: FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/MusicRouter.log"),
        isEnabled: { Config.debugLogging }
    )

    let url: URL
    private let maxBytes: Int
    private let isEnabled: () -> Bool
    private let queue = DispatchQueue(label: "dev.drumandbytes.musicrouter.log")
    private var lastCollapsible: String?
    private var repeats = 0

    init(url: URL, maxBytes: Int = 2_000_000, isEnabled: @escaping () -> Bool) {
        self.url = url
        self.maxBytes = maxBytes
        self.isEnabled = isEnabled
    }

    var rotatedURL: URL { url.appendingPathExtension("1") }

    /// `collapseRepeats`: identical consecutive messages are counted, not
    /// written (a stream that dies every 2s would otherwise flood the file).
    /// The message is an autoclosure so the off path builds no strings.
    func log(_ message: @autoclosure () -> String, collapseRepeats: Bool = false) {
        guard isEnabled() else { return }
        let text = message()
        let now = Date()
        queue.async { [self] in
            if collapseRepeats, text == lastCollapsible {
                repeats += 1
                return
            }
            if repeats > 0 {
                append("(previous message repeated \(repeats) more times)", at: now)
            }
            repeats = 0
            lastCollapsible = collapseRepeats ? text : nil
            append(text, at: now)
        }
    }

    /// Blocks until queued writes land; for tests.
    func flush() { queue.sync {} }

    private func append(_ text: String, at date: Date) {
        let line = "\(Self.timestamp(date)) \(text)\n"
        let fm = FileManager.default
        if let size = (try? fm.attributesOfItem(atPath: url.path))?[.size] as? Int, size >= maxBytes {
            try? fm.removeItem(at: rotatedURL)
            try? fm.moveItem(at: url, to: rotatedURL)
        }
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            fm.createFile(atPath: url.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data(line.utf8))
    }

    private static func timestamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f.string(from: date)
    }
}

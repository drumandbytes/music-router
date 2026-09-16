import Foundation

/// Tracks whether *something* is already registered as the system's Now
/// Playing session — native app or a browser tab, anything using the Media
/// Session/MediaRemote machinery — via the `media-control` CLI
/// (https://formulae.brew.sh/formula/media-control, a Homebrew dependency
/// declared on the cask). No public API exposes this; `media-control` wraps
/// the private `MediaRemote` framework so we don't have to vendor it.
///
/// Runs `media-control stream` once as a long-lived subprocess and caches
/// the latest state in memory, so each media-key press just reads an
/// already-current flag — no subprocess spawn on the key-press path.
final class NowPlayingObserver {
    private static let executablePaths = [
        "/opt/homebrew/bin/media-control",
        "/usr/local/bin/media-control",
    ]

    private(set) var isSomethingOpen = false
    private var process: Process?
    private var pipe: Pipe?
    private var buffer = Data()

    func start() {
        guard process == nil,
              let path = Self.executablePaths.first(where: { FileManager.default.fileExists(atPath: $0) })
        else { return }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = ["stream", "--no-diff", "--no-artwork"]

        let pipe = Pipe()
        task.standardOutput = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            // Pipe callbacks fire on a background thread, but `stop()` (from
            // the main thread) also touches `buffer` — hop to main so it's
            // never mutated from two threads at once.
            DispatchQueue.main.async { self?.consume(chunk) }
        }

        do {
            try task.run()
            process = task
            self.pipe = pipe
        } catch {
            NSLog("MusicRouter: failed to start media-control stream: \(error)")
        }
    }

    func stop() {
        pipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        process = nil
        pipe = nil
        buffer.removeAll()
    }

    /// `stream` emits newline-delimited JSON; with `--no-diff` each line is
    /// a full snapshot, so no diff-merging is needed — just the latest line.
    private func consume(_ chunk: Data) {
        buffer.append(chunk)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer.subdata(in: buffer.startIndex..<newline)
            buffer.removeSubrange(buffer.startIndex...newline)
            if let open = Self.hasNowPlayingApp(jsonLine: line) {
                DispatchQueue.main.async { [weak self] in self?.isSomethingOpen = open }
            }
        }
    }

    /// Pure so it's directly testable with sample stream-line JSON without a
    /// running subprocess. `nil` means the line didn't parse (ignored by the
    /// caller — keeps the last known state rather than resetting to false).
    static func hasNowPlayingApp(jsonLine: Data) -> Bool? {
        struct StreamLine: Decodable {
            struct Payload: Decodable { let bundleIdentifier: String? }
            let payload: Payload
        }
        guard let line = try? JSONDecoder().decode(StreamLine.self, from: jsonLine) else { return nil }
        return line.payload.bundleIdentifier != nil
    }
}

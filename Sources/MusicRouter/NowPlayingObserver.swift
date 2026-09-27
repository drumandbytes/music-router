import Foundation

/// Tracks whether anything owns Now Playing (native app or browser tab) via
/// the `media-control` CLI, which wraps private MediaRemote. One long-lived
/// `media-control stream` keeps a cached flag, so key presses spawn nothing.
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
            // pipe callbacks are off-main; stop() touches buffer on main
            DispatchQueue.main.async { self?.consume(chunk) }
        }

        // EOF alone is invisible (empty data is ignored), so on child exit fall
        // back to false (safe default) and clear process/pipe so start() can
        // relaunch; else isSomethingOpen could stick "true" forever.
        task.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isSomethingOpen = false
                self?.process = nil
                self?.pipe = nil
            }
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

    /// With `--no-diff` each line is a full snapshot; only the latest matters.
    private func consume(_ chunk: Data) {
        buffer.append(chunk)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer.subdata(in: buffer.startIndex..<newline)
            buffer.removeSubrange(buffer.startIndex...newline)
            if let open = Self.hasNowPlayingApp(jsonLine: line) {
                isSomethingOpen = open
            }
        }
    }

    /// `nil` = unparseable line; caller keeps the last known state.
    static func hasNowPlayingApp(jsonLine: Data) -> Bool? {
        struct StreamLine: Decodable {
            struct Payload: Decodable { let bundleIdentifier: String? }
            let payload: Payload
        }
        guard let line = try? JSONDecoder().decode(StreamLine.self, from: jsonLine) else { return nil }
        return line.payload.bundleIdentifier != nil
    }
}

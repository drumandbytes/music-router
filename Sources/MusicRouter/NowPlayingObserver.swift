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
    private var wantsRunning = false
    private var lastBundleID: String?

    func start() {
        wantsRunning = true
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
        // back to false (safe default) and clear process/pipe, then relaunch:
        // a dead stream would otherwise pin isSomethingOpen at false and send
        // every media key to the replacement app. The identity check skips
        // exits from stop() and from an already-replaced child.
        task.terminationHandler = { [weak self, weak task] _ in
            DispatchQueue.main.async {
                guard let self, let task, self.process === task else { return }
                DebugLog.shared.log("media-control stream exited, restarting in 2s", collapseRepeats: true)
                self.isSomethingOpen = false
                self.lastBundleID = nil
                self.process = nil
                self.pipe = nil
                self.buffer.removeAll()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    guard let self, self.wantsRunning else { return }
                    self.start()
                }
            }
        }

        do {
            try task.run()
            DebugLog.shared.log("media-control stream started")
            process = task
            self.pipe = pipe
        } catch {
            NSLog("MusicRouter: failed to start media-control stream: \(error)")
            DebugLog.shared.log("media-control stream failed to start: \(error)", collapseRepeats: true)
        }
    }

    func stop() {
        wantsRunning = false
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
            if let bundleID = Self.parse(jsonLine: line) {
                isSomethingOpen = bundleID != nil
                if bundleID != lastBundleID {
                    DebugLog.shared.log("nowPlaying owner=\(bundleID ?? "none")")
                    lastBundleID = bundleID
                }
            }
        }
    }

    /// Outer `nil` = unparseable line (caller keeps the last known state);
    /// inner `nil` = parsed, nothing owns Now Playing.
    static func parse(jsonLine: Data) -> String?? {
        struct StreamLine: Decodable {
            struct Payload: Decodable { let bundleIdentifier: String? }
            let payload: Payload
        }
        guard let line = try? JSONDecoder().decode(StreamLine.self, from: jsonLine) else { return nil }
        return .some(line.payload.bundleIdentifier)
    }

    static func hasNowPlayingApp(jsonLine: Data) -> Bool? {
        parse(jsonLine: jsonLine).map { $0 != nil }
    }
}

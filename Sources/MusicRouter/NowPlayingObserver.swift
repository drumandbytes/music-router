import Foundation

/// Tracks whether anything owns Now Playing (native app or browser tab) via
/// the vendored mediaremote-adapter (third_party/mediaremote-adapter, BSD-3).
/// MediaRemote only answers Apple-signed processes, so we run the adapter's
/// perl script under /usr/bin/perl (com.apple.perl5), which dlopens the
/// bundled framework. One long-lived `stream` keeps a cached flag, so key
/// presses spawn nothing.
final class NowPlayingObserver {
    static let perlPath = "/usr/bin/perl"

    /// Script + framework inside the app bundle, nil when not bundled
    /// (e.g. `swift run`).
    static func adapterPaths(in bundle: Bundle = .main) -> (script: String, framework: String)? {
        guard let script = bundle.url(forResource: "mediaremote-adapter", withExtension: "pl"),
              let frameworks = bundle.privateFrameworksURL
        else { return nil }
        let framework = frameworks.appendingPathComponent("MediaRemoteAdapter.framework")
        let fm = FileManager.default
        guard fm.fileExists(atPath: script.path), fm.fileExists(atPath: framework.path) else { return nil }
        return (script.path, framework.path)
    }

    private(set) var isSomethingOpen = false
    private var process: Process?
    private var pipe: Pipe?
    private var buffer = Data()
    private var wantsRunning = false
    private var lastBundleID: String?

    func start() {
        wantsRunning = true
        guard process == nil,
              let adapter = Self.adapterPaths(),
              FileManager.default.isExecutableFile(atPath: Self.perlPath)
        else { return }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: Self.perlPath)
        task.arguments = [adapter.script, adapter.framework, "stream", "--no-diff", "--no-artwork"]

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
                DebugLog.shared.log("mediaremote-adapter stream exited, restarting in 2s", collapseRepeats: true)
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
            DebugLog.shared.log("mediaremote-adapter stream started")
            process = task
            self.pipe = pipe
        } catch {
            NSLog("MusicRouter: failed to start mediaremote-adapter stream: \(error)")
            DebugLog.shared.log("mediaremote-adapter stream failed to start: \(error)", collapseRepeats: true)
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

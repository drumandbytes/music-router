import Foundation

/// Tracks whether anything owns Now Playing (native app or browser tab) via
/// the vendored mediaremote-adapter (third_party/mediaremote-adapter, BSD-3).
/// MediaRemote only answers Apple-signed processes, so we run the adapter's
/// perl script under /usr/bin/perl (com.apple.perl5), which dlopens the
/// bundled framework. One long-lived `stream` keeps a cached flag, so key
/// presses spawn nothing.
final class NowPlayingObserver {
    enum Health: Equatable {
        /// Adapter launched, no data yet.
        case starting
        case ok
        /// Detection is down; the reason is shown in Settings.
        case failed(String)
    }

    static let perlPath = "/usr/bin/perl"
    static let healthChangedNotification = Notification.Name("MusicRouterNowPlayingHealthChanged")

    private let perl: String
    private let adapter: (script: String, framework: String)?
    private let audioProbe: () -> Bool
    private let watchdogInterval: TimeInterval
    private let restartDelays: [TimeInterval]

    private(set) var health: Health = .starting {
        didSet {
            guard health != oldValue else { return }
            DebugLog.shared.log("nowPlaying health=\(health)")
            NotificationCenter.default.post(name: Self.healthChangedNotification, object: self)
        }
    }

    /// Defaults are the production wiring; tests inject a fake perl/script and
    /// short timers.
    init(
        perl: String = NowPlayingObserver.perlPath,
        adapter: (script: String, framework: String)? = NowPlayingObserver.adapterPaths(),
        audioProbe: @escaping () -> Bool = AudioActivity.isOutputRunning,
        watchdogInterval: TimeInterval = 5,
        restartDelays: [TimeInterval] = [2, 5, 15, 60]
    ) {
        self.perl = perl
        self.adapter = adapter
        self.audioProbe = audioProbe
        self.watchdogInterval = watchdogInterval
        self.restartDelays = restartDelays
    }

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

    /// Adapter state when it's healthy, otherwise the CoreAudio fallback
    /// (see `AudioActivity`). Never blocks: both paths are a cached flag or a
    /// couple of property reads.
    var isSomethingOpen: Bool {
        if case .ok = health { return adapterSaysOpen }
        return audioProbe()
    }

    private var adapterSaysOpen = false
    private var consecutiveFailures = 0
    private var watchdog: DispatchWorkItem?
    private var process: Process?
    private var pipe: Pipe?
    private var buffer = Data()
    private var wantsRunning = false
    private var lastBundleID: String?

    func start() {
        wantsRunning = true
        guard process == nil else { return }
        guard let adapter else {
            fail("adapter not bundled with this build")
            return
        }
        guard FileManager.default.isExecutableFile(atPath: perl) else {
            fail("perl not found at \(perl)")
            return
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: perl)
        task.arguments = [adapter.script, adapter.framework, "stream", "--no-diff", "--no-artwork"]
        task.standardError = FileHandle.nullDevice

        let pipe = Pipe()
        task.standardOutput = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            // pipe callbacks are off-main; stop() touches buffer on main
            DispatchQueue.main.async { self?.consume(chunk) }
        }

        // EOF alone is invisible (empty data is ignored), so on child exit mark
        // detection failed (key presses then use the audio fallback), clear
        // process/pipe and relaunch with backoff. The identity check skips
        // exits from stop() and from an already-replaced child.
        task.terminationHandler = { [weak self, weak task] finished in
            DispatchQueue.main.async {
                guard let self, let task, self.process === task else { return }
                self.process = nil
                self.pipe = nil
                self.buffer.removeAll()
                self.cancelWatchdog()
                self.lastBundleID = nil
                self.adapterSaysOpen = false
                self.fail("adapter exited (status \(finished.terminationStatus))")
                self.scheduleRestart()
            }
        }

        do {
            try task.run()
            DebugLog.shared.log("mediaremote-adapter stream started")
            process = task
            self.pipe = pipe
            // keep a visible failure until real data arrives, so the status doesn't flap on each retry
            if case .failed = health {} else { health = .starting }
            armWatchdog()
        } catch {
            NSLog("MusicRouter: failed to start mediaremote-adapter stream: \(error)")
            fail("could not start adapter: \(error.localizedDescription)")
            scheduleRestart()
        }
    }

    private func fail(_ reason: String) {
        adapterSaysOpen = false
        health = .failed(reason)
    }

    /// The adapter prints a snapshot as soon as it starts, even with nothing
    /// playing. No line within the interval means it can't reach MediaRemote
    /// (macOS update, entitlement change), so fall back until data shows up.
    private func armWatchdog() {
        cancelWatchdog()
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.process != nil, self.health == .starting else { return }
            self.fail("no response from adapter")
        }
        watchdog = item
        DispatchQueue.main.asyncAfter(deadline: .now() + watchdogInterval, execute: item)
    }

    private func cancelWatchdog() {
        watchdog?.cancel()
        watchdog = nil
    }

    private func scheduleRestart() {
        guard wantsRunning, !restartDelays.isEmpty else { return }
        let delay = restartDelays[min(consecutiveFailures, restartDelays.count - 1)]
        consecutiveFailures += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.wantsRunning, self.process == nil else { return }
            self.start()
        }
    }

    func stop() {
        wantsRunning = false
        cancelWatchdog()
        adapterSaysOpen = false
        consecutiveFailures = 0
        health = .starting
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
                cancelWatchdog()
                consecutiveFailures = 0
                health = .ok
                adapterSaysOpen = bundleID != nil
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

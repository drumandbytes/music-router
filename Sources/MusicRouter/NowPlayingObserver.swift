import Foundation

/// Now Playing via the vendored mediaremote-adapter. MediaRemote only answers
/// Apple-signed processes, so its perl script runs under /usr/bin/perl
/// (com.apple.perl5) and dlopens the bundled framework. One long-lived `stream`
/// keeps a cached flag; key presses spawn nothing.
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
    private let syncCheckInterval: TimeInterval
    private let syncChecksBeforeVerify: Int
    private let verifyCooldown: TimeInterval
    /// One-shot `get` against the adapter, off the main thread. Outer nil =
    /// couldn't run; inner nil = nothing is playing.
    private let snapshot: (@escaping (String??) -> Void) -> Void

    private(set) var health: Health = .starting {
        didSet {
            guard health != oldValue else { return }
            DebugLog.shared.log("nowPlaying health=\(health)")
            NotificationCenter.default.post(name: Self.healthChangedNotification, object: self)
        }
    }

    /// Tests inject a fake perl/script and short timers.
    init(
        perl: String = NowPlayingObserver.perlPath,
        adapter: (script: String, framework: String)? = NowPlayingObserver.adapterPaths(),
        audioProbe: @escaping () -> Bool = AudioActivity.isOutputRunning,
        watchdogInterval: TimeInterval = 5,
        restartDelays: [TimeInterval] = [2, 5, 15, 60],
        syncCheckInterval: TimeInterval = 5,
        syncChecksBeforeVerify: Int = 3,
        verifyCooldown: TimeInterval = 60,
        snapshot: ((@escaping (String??) -> Void) -> Void)? = nil
    ) {
        self.perl = perl
        self.adapter = adapter
        self.audioProbe = audioProbe
        self.watchdogInterval = watchdogInterval
        self.restartDelays = restartDelays
        self.syncCheckInterval = syncCheckInterval
        self.syncChecksBeforeVerify = syncChecksBeforeVerify
        self.verifyCooldown = verifyCooldown
        self.snapshot = snapshot ?? { completion in
            guard let adapter else { return completion(nil) }
            Self.runSnapshot(perl: perl, adapter: adapter, completion: completion)
        }
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

    /// Adapter state when healthy, else the CoreAudio fallback. Both are cheap enough for the key path.
    var isSomethingOpen: Bool {
        if case .ok = health { return adapterSaysOpen }
        return audioProbe()
    }

    /// Last app reported as playing; in-memory, nil until something plays after launch.
    private(set) var lastPlayingBundleID: String?

    private var adapterSaysOpen = false
    private var consecutiveFailures = 0
    private var watchdog: DispatchWorkItem?
    private var syncTimer: Timer?
    private var disagreements = 0
    private var verifying = false
    private var nextVerify = Date.distantPast
    private var forcedFailure: String?
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
                self.stopSyncTimer()
                self.fail(self.forcedFailure ?? "adapter exited (status \(finished.terminationStatus))")
                self.forcedFailure = nil
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
            startSyncTimer()
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

    /// The adapter prints a snapshot right away, even when idle; silence means it
    /// can't reach MediaRemote (macOS update, entitlements). Fall back until data shows up.
    private func armWatchdog() {
        cancelWatchdog()
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.process != nil, self.health == .starting else { return }
            self.fail("no response from adapter")
        }
        watchdog = item
        DispatchQueue.main.asyncAfter(deadline: .now() + watchdogInterval, execute: item)
    }

    // MARK: stale-stream detection

    /// The stream only prints on change, so a stalled adapter reads as "nothing
    /// playing" forever. If it says so while audio runs, ask once via `get`
    /// (independent of the stream): a player in the answer means the stream is
    /// stale, so restart it. Unrelated audio (a call) just earns a cooldown.
    private func startSyncTimer() {
        stopSyncTimer()
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncCheckInterval, repeats: true) { [weak self] _ in
            self?.syncCheck()
        }
    }

    private func stopSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = nil
        disagreements = 0
        verifying = false
    }

    private func syncCheck() {
        guard case .ok = health, !adapterSaysOpen, audioProbe() else {
            disagreements = 0
            return
        }
        disagreements += 1
        guard disagreements >= syncChecksBeforeVerify, !verifying, Date() >= nextVerify else { return }
        verifying = true
        let current = process
        snapshot { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.verifying = false
                self.nextVerify = Date().addingTimeInterval(self.verifyCooldown)
                self.disagreements = 0
                guard self.process === current, let current,
                      case .some(.some(let owner)) = result else { return }
                DebugLog.shared.log("stream stale: get reports owner=\(owner)")
                self.forcedFailure = "adapter out of sync"
                kill(current.processIdentifier, SIGKILL)
            }
        }
    }

    /// `get` prints `null` when nothing plays, else the payload dictionary.
    static func parseSnapshot(_ data: Data) -> String?? {
        struct Payload: Decodable { let bundleIdentifier: String? }
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        if text == "null" { return .some(nil) }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: Data(text.utf8)) else { return nil }
        return .some(payload.bundleIdentifier)
    }

    private static func runSnapshot(
        perl: String,
        adapter: (script: String, framework: String),
        completion: @escaping (String??) -> Void
    ) {
        DispatchQueue.global(qos: .utility).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: perl)
            task.arguments = [adapter.script, adapter.framework, "get", "--no-artwork"]
            let out = Pipe()
            task.standardOutput = out
            task.standardError = FileHandle.nullDevice
            do { try task.run() } catch { return completion(nil) }
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) { if task.isRunning { task.terminate() } }
            let data = out.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            completion(task.terminationStatus == 0 ? parseSnapshot(data) : nil)
        }
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
        stopSyncTimer()
        adapterSaysOpen = false
        consecutiveFailures = 0
        forcedFailure = nil
        health = .starting
        pipe?.fileHandleForReading.readabilityHandler = nil
        // SIGKILL: a stalled (SIGSTOPped) child ignores SIGTERM and would leak
        if let pid = process?.processIdentifier, pid > 0 { kill(pid, SIGKILL) }
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
            if let state = Self.parseState(jsonLine: line) {
                let bundleID = state.bundleID
                if state.playing, let bundleID, bundleID != lastPlayingBundleID {
                    lastPlayingBundleID = bundleID
                    DebugLog.shared.log("lastPlaying=\(bundleID)")
                }
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

    struct State: Equatable {
        let bundleID: String?
        let playing: Bool
    }

    /// `nil` = unparseable line (caller keeps the last known state).
    static func parseState(jsonLine: Data) -> State? {
        struct StreamLine: Decodable {
            struct Payload: Decodable {
                let bundleIdentifier: String?
                let playing: Bool?
            }
            let payload: Payload
        }
        guard let line = try? JSONDecoder().decode(StreamLine.self, from: jsonLine) else { return nil }
        return State(bundleID: line.payload.bundleIdentifier, playing: line.payload.playing ?? false)
    }

    /// Outer `nil` = unparseable line; inner `nil` = parsed, nothing owns Now Playing.
    static func parse(jsonLine: Data) -> String?? {
        guard let state = parseState(jsonLine: jsonLine) else { return nil }
        return .some(state.bundleID)
    }

    static func hasNowPlayingApp(jsonLine: Data) -> Bool? {
        parse(jsonLine: jsonLine).map { $0 != nil }
    }
}

import XCTest
@testable import MusicRouter

final class NowPlayingObserverTests: XCTestCase {
    func testDetectsNowPlayingApp() {
        let line = #"{"type":"data","diff":false,"payload":{"bundleIdentifier":"com.spotify.client","playing":true,"title":"Song"}}"#
        XCTAssertEqual(NowPlayingObserver.hasNowPlayingApp(jsonLine: Data(line.utf8)), true)
    }

    func testDetectsNothingPlaying() {
        let line = #"{"type":"data","diff":false,"payload":{}}"#
        XCTAssertEqual(NowPlayingObserver.hasNowPlayingApp(jsonLine: Data(line.utf8)), false)
    }

    func testDetectsExplicitNullBundleID() {
        let line = #"{"type":"data","diff":false,"payload":{"bundleIdentifier":null}}"#
        XCTAssertEqual(NowPlayingObserver.hasNowPlayingApp(jsonLine: Data(line.utf8)), false)
    }

    func testReturnsNilForUnparsableLine() {
        XCTAssertNil(NowPlayingObserver.hasNowPlayingApp(jsonLine: Data("not json".utf8)))
    }

    func testParseExposesBundleID() {
        let line = #"{"type":"data","diff":false,"payload":{"bundleIdentifier":"com.brave.Browser","title":"secret"}}"#
        XCTAssertEqual(NowPlayingObserver.parse(jsonLine: Data(line.utf8)), .some("com.brave.Browser"))
    }

    func testParseDistinguishesNothingPlayingFromUnparsable() {
        let empty = NowPlayingObserver.parse(jsonLine: Data(#"{"payload":{}}"#.utf8))
        XCTAssertNotNil(empty)
        XCTAssertNil(empty!)
        XCTAssertNil(NowPlayingObserver.parse(jsonLine: Data("nope".utf8)))
    }

    func testAdapterPathsNilWhenNotBundled() {
        // the xctest bundle has neither the script nor the framework
        XCTAssertNil(NowPlayingObserver.adapterPaths(in: Bundle(for: NowPlayingObserverTests.self)))
    }

    func testPerlHostExists() {
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: NowPlayingObserver.perlPath))
    }

    // MARK: failure path (a fake "perl" runs a shell script as the adapter)

    private func script(_ body: String) throws -> (script: String, framework: String) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("adapter-\(UUID().uuidString).sh")
        try body.write(to: url, atomically: true, encoding: .utf8)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return (url.path, "/unused")
    }

    private func makeObserver(
        adapter: (script: String, framework: String)?,
        perl: String = "/bin/sh",
        audio: Bool = false,
        watchdog: TimeInterval = 0.3
    ) -> NowPlayingObserver {
        NowPlayingObserver(perl: perl, adapter: adapter, audioProbe: { audio },
                           watchdogInterval: watchdog, restartDelays: [30])
    }

    private func wait(for observer: NowPlayingObserver, until predicate: (NowPlayingObserver.Health) -> Bool) {
        let deadline = Date().addingTimeInterval(5)
        while !predicate(observer.health), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
    }

    func testMissingAdapterFailsAndFallsBackToAudio() {
        let quiet = makeObserver(adapter: nil, audio: false)
        quiet.start()
        XCTAssertEqual(quiet.health, .failed("adapter not bundled with this build"))
        XCTAssertFalse(quiet.isSomethingOpen)

        let loud = makeObserver(adapter: nil, audio: true)
        loud.start()
        XCTAssertTrue(loud.isSomethingOpen)
        quiet.stop(); loud.stop()
    }

    func testMissingPerlFails() throws {
        let observer = makeObserver(adapter: try script("exit 0"), perl: "/nonexistent/perl")
        observer.start()
        XCTAssertEqual(observer.health, .failed("perl not found at /nonexistent/perl"))
        observer.stop()
    }

    func testAdapterExitingMarksFailedAndUsesFallback() throws {
        let observer = makeObserver(adapter: try script("exit 3"), audio: true)
        observer.start()
        wait(for: observer) { if case .failed = $0 { return true } else { return false } }
        XCTAssertEqual(observer.health, .failed("adapter exited (status 3)"))
        XCTAssertTrue(observer.isSomethingOpen)
        observer.stop()
    }

    func testSilentAdapterTripsWatchdog() throws {
        let observer = makeObserver(adapter: try script("sleep 30"), audio: true, watchdog: 0.2)
        observer.start()
        XCTAssertEqual(observer.health, .starting)
        wait(for: observer) { $0 != .starting }
        XCTAssertEqual(observer.health, .failed("no response from adapter"))
        XCTAssertTrue(observer.isSomethingOpen)
        observer.stop()
    }

    func testHealthyAdapterUsesItsOwnStateNotAudio() throws {
        // audio says "running" but the adapter says nothing is open: adapter wins
        let observer = makeObserver(adapter: try script(#"echo '{"type":"data","diff":false,"payload":{}}'; sleep 30"#), audio: true)
        observer.start()
        wait(for: observer) { $0 == .ok }
        XCTAssertEqual(observer.health, .ok)
        XCTAssertFalse(observer.isSomethingOpen)
        observer.stop()
    }

    func testHealthyAdapterReportsOpenOwner() throws {
        let line = #"{"type":"data","diff":false,"payload":{"bundleIdentifier":"com.spotify.client"}}"#
        let observer = makeObserver(adapter: try script("echo '\(line)'; sleep 30"), audio: false)
        observer.start()
        wait(for: observer) { $0 == .ok }
        XCTAssertTrue(observer.isSomethingOpen)
        observer.stop()
    }

    func testDataAfterFailureRecovers() throws {
        let line = #"{"type":"data","diff":false,"payload":{}}"#
        // silent past the watchdog, then emits a snapshot
        let observer = makeObserver(adapter: try script("sleep 0.6; echo '\(line)'; sleep 30"), watchdog: 0.2)
        observer.start()
        wait(for: observer) { $0 != .starting }
        XCTAssertEqual(observer.health, .failed("no response from adapter"))
        wait(for: observer) { $0 == .ok }
        XCTAssertEqual(observer.health, .ok)
        observer.stop()
    }

    func testStatusText() {
        XCTAssertEqual(SettingsView.statusText(.ok, enabled: false), "Off")
        XCTAssertEqual(SettingsView.statusText(.ok, enabled: true), "Working")
        XCTAssertEqual(SettingsView.statusText(.starting, enabled: true), "Starting…")
        XCTAssertEqual(SettingsView.statusText(.failed("x"), enabled: true), "Unavailable: x")
    }

    // MARK: stale stream

    private let emptySnapshot = #"echo '{"type":"data","diff":false,"payload":{}}'; sleep 30"#

    private func staleObserver(snapshot: @escaping (@escaping (String??) -> Void) -> Void) throws -> NowPlayingObserver {
        NowPlayingObserver(
            perl: "/bin/sh", adapter: try script(emptySnapshot), audioProbe: { true },
            watchdogInterval: 5, restartDelays: [30],
            syncCheckInterval: 0.05, syncChecksBeforeVerify: 2, verifyCooldown: 30,
            snapshot: snapshot
        )
    }

    func testStaleStreamIsDetectedAndFallsBack() throws {
        let observer = try staleObserver { $0("com.spotify.client") }
        observer.start()
        wait(for: observer) { $0 == .ok }
        wait(for: observer) { $0 != .ok }
        XCTAssertEqual(observer.health, .failed("adapter out of sync"))
        XCTAssertTrue(observer.isSomethingOpen) // audio fallback
        observer.stop()
    }

    func testUnrelatedAudioDoesNotFailAdapter() throws {
        var calls = 0
        let observer = try staleObserver { calls += 1; $0(.some(nil)) }
        observer.start()
        wait(for: observer) { $0 == .ok }
        let end = Date().addingTimeInterval(0.6)
        while Date() < end { RunLoop.current.run(until: Date().addingTimeInterval(0.02)) }
        XCTAssertEqual(observer.health, .ok)
        XCTAssertEqual(calls, 1) // cooldown stops re-probing
        observer.stop()
    }

    func testParseSnapshot() {
        XCTAssertEqual(NowPlayingObserver.parseSnapshot(Data("null\n".utf8)), .some(nil))
        XCTAssertEqual(NowPlayingObserver.parseSnapshot(Data(#"{"bundleIdentifier":"a.b","title":"t"}"#.utf8)), .some("a.b"))
        XCTAssertEqual(NowPlayingObserver.parseSnapshot(Data("{}".utf8)), .some(nil))
        XCTAssertNil(NowPlayingObserver.parseSnapshot(Data("garbage".utf8)))
    }

    // MARK: last player

    func testParseStateReadsPlaying() {
        let playing = #"{"payload":{"bundleIdentifier":"com.spotify.client","playing":true}}"#
        let paused = #"{"payload":{"bundleIdentifier":"com.spotify.client","playing":false}}"#
        let none = #"{"payload":{}}"#
        XCTAssertEqual(NowPlayingObserver.parseState(jsonLine: Data(playing.utf8)),
                       .init(bundleID: "com.spotify.client", playing: true))
        XCTAssertEqual(NowPlayingObserver.parseState(jsonLine: Data(paused.utf8))?.playing, false)
        XCTAssertEqual(NowPlayingObserver.parseState(jsonLine: Data(none.utf8)), .init(bundleID: nil, playing: false))
        XCTAssertNil(NowPlayingObserver.parseState(jsonLine: Data("nope".utf8)))
    }

    func testTracksLastPlayingNotPausedOwner() throws {
        let playing = #"{"payload":{"bundleIdentifier":"com.spotify.client","playing":true}}"#
        let paused = #"{"payload":{"bundleIdentifier":"org.videolan.vlc","playing":false}}"#
        let none = #"{"payload":{}}"#
        let observer = makeObserver(adapter: try script("echo '\(playing)'; echo '\(paused)'; echo '\(none)'; sleep 30"))
        observer.start()
        let end = Date().addingTimeInterval(1)
        while Date() < end { RunLoop.current.run(until: Date().addingTimeInterval(0.02)) }
        XCTAssertEqual(observer.lastPlayingBundleID, "com.spotify.client")
        observer.stop()
    }
}

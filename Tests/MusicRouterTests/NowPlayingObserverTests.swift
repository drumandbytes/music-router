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
}

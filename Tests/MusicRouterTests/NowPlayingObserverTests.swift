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
}

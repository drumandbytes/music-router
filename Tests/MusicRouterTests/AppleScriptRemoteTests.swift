import XCTest
@testable import MusicRouter

final class AppleScriptRemoteTests: XCTestCase {
    func testVerbForPlayPause() {
        XCTAssertEqual(AppleScriptRemote.verb(for: .playPause), "playpause")
    }

    func testVerbForNext() {
        XCTAssertEqual(AppleScriptRemote.verb(for: .next), "next track")
    }

    func testVerbForPrevious() {
        XCTAssertEqual(AppleScriptRemote.verb(for: .previous), "previous track")
    }

    func testSourceTargetsBundleID() {
        XCTAssertEqual(AppleScriptRemote.source(for: .next, bundleID: "com.spotify.client"),
                       #"tell application id "com.spotify.client" to next track"#)
    }
}

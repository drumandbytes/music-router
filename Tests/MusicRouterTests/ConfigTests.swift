import XCTest
@testable import MusicRouter

final class ConfigTests: XCTestCase {
    override func tearDown() {
        // Leave UserDefaults as we found it — Config reads/writes
        // UserDefaults.standard directly, keyed by this test process's own
        // bundle id, not the real app's, but still worth not leaking state
        // between tests.
        Config.replacement = nil
        Config.hasRequestedPermissions = false
        Config.menuBarIconHidden = false
        super.tearDown()
    }

    func testIsWebURLAcceptsHttpAndHttps() {
        XCTAssertTrue(Config.isWebURL("https://music.youtube.com/"))
        XCTAssertTrue(Config.isWebURL("http://example.com"))
    }

    func testIsWebURLRejectsFilePaths() {
        XCTAssertFalse(Config.isWebURL("/Applications/Spotify.app"))
        XCTAssertFalse(Config.isWebURL("Spotify.app"))
        XCTAssertFalse(Config.isWebURL(""))
    }

    func testReplacementRoundTrip() {
        XCTAssertNil(Config.replacement)

        Config.replacement = "/Applications/Spotify.app"
        XCTAssertEqual(Config.replacement, "/Applications/Spotify.app")

        Config.replacement = nil
        XCTAssertNil(Config.replacement)
    }

    func testHasRequestedPermissionsDefaultsFalse() {
        XCTAssertFalse(Config.hasRequestedPermissions)
        Config.hasRequestedPermissions = true
        XCTAssertTrue(Config.hasRequestedPermissions)
    }

    func testMenuBarIconHiddenDefaultsFalse() {
        XCTAssertFalse(Config.menuBarIconHidden)
        Config.menuBarIconHidden = true
        XCTAssertTrue(Config.menuBarIconHidden)
    }
}

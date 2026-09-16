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
        // Removed rather than set, so the default-true path is what the next
        // test sees.
        UserDefaults.standard.removeObject(forKey: "enabled")
        super.tearDown()
    }

    func testIsEnabledDefaultsTrueAndPersistsFalse() {
        XCTAssertTrue(Config.isEnabled)
        Config.isEnabled = false
        XCTAssertFalse(Config.isEnabled)
    }

    func testReplacementIsMissingOnlyForAbsentNativePaths() {
        XCTAssertFalse(Config.replacementIsMissing, "block-only isn't missing")

        Config.replacement = "https://music.youtube.com/"
        XCTAssertFalse(Config.replacementIsMissing, "web URLs have nothing to check")

        Config.replacement = "/System/Applications/Calculator.app"
        XCTAssertFalse(Config.replacementIsMissing)

        Config.replacement = "/Applications/Definitely-Not-Installed-\(UUID()).app"
        XCTAssertTrue(Config.replacementIsMissing)
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

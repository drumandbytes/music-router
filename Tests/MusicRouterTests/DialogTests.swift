import XCTest
@testable import MusicRouter

final class DialogTests: XCTestCase {
    func testUrlErrorAcceptsHttpAndHttps() {
        XCTAssertNil(Config.urlError("https://music.youtube.com/"))
        XCTAssertNil(Config.urlError("  http://localhost:8080  "))
    }

    func testUrlErrorRejectsEmptyAndNonWeb() {
        XCTAssertEqual(Config.urlError("   "), "Enter a URL.")
        XCTAssertNotNil(Config.urlError("/Applications/Spotify.app"))
        XCTAssertNotNil(Config.urlError("ftp://example.com"))
        XCTAssertNotNil(Config.urlError("spotify"))
    }

    func testAboutVersionText() {
        XCTAssertEqual(AboutView.versionText(short: "1.0.0", build: "1.0.0"), "Version 1.0.0")
        XCTAssertEqual(AboutView.versionText(short: "1.0.0", build: "42"), "Version 1.0.0 (42)")
        XCTAssertEqual(AboutView.versionText(short: nil, build: nil), "Development build")
    }

    func testLinksPointAtTheRepo() {
        XCTAssertTrue(Links.help.absoluteString.hasSuffix("/docs/help.md"))
        XCTAssertEqual(Links.projects.host, "drumandbytes.com")
    }
}

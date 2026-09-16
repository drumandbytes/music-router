import XCTest
@testable import MusicRouter

final class MusicLauncherGuardTests: XCTestCase {
    func testBlocksMusic() {
        XCTAssertTrue(MusicLauncherGuard.shouldBlock(bundleID: "com.apple.Music"))
    }

    func testBlocksITunes() {
        XCTAssertTrue(MusicLauncherGuard.shouldBlock(bundleID: "com.apple.iTunes"))
    }

    func testDoesNotBlockOtherApps() {
        XCTAssertFalse(MusicLauncherGuard.shouldBlock(bundleID: "com.spotify.client"))
    }

    func testDoesNotBlockNilBundleID() {
        XCTAssertFalse(MusicLauncherGuard.shouldBlock(bundleID: nil))
    }
}

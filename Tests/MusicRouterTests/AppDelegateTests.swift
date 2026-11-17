import XCTest
@testable import MusicRouter

final class AppDelegateTests: XCTestCase {
    func testPressSwallowsWhenNothingIsPlaying() {
        XCTAssertTrue(AppDelegate.decideSwallow(isPressed: true, isSomethingOpen: false, lastKeySwallowed: false))
    }

    func testPressPassesThroughWhenSomethingIsPlaying() {
        XCTAssertFalse(AppDelegate.decideSwallow(isPressed: true, isSomethingOpen: true, lastKeySwallowed: true))
    }

    func testReleaseMirrorsPriorSwallowedPress() {
        XCTAssertTrue(AppDelegate.decideSwallow(isPressed: false, isSomethingOpen: true, lastKeySwallowed: true))
    }

    func testReleaseMirrorsPriorPassedThroughPress() {
        XCTAssertFalse(AppDelegate.decideSwallow(isPressed: false, isSomethingOpen: false, lastKeySwallowed: false))
    }

    func testResumeTargetWhenRunning() {
        XCTAssertEqual(AppDelegate.resumeTarget(enabled: true, lastPlaying: "com.spotify.client", isRunning: { _ in true }),
                       "com.spotify.client")
    }

    func testResumeTargetNilWhenDisabledNotRunningOrUnknown() {
        XCTAssertNil(AppDelegate.resumeTarget(enabled: false, lastPlaying: "com.spotify.client", isRunning: { _ in true }))
        XCTAssertNil(AppDelegate.resumeTarget(enabled: true, lastPlaying: "com.spotify.client", isRunning: { _ in false }))
        XCTAssertNil(AppDelegate.resumeTarget(enabled: true, lastPlaying: nil, isRunning: { _ in true }))
    }

    func testResumeTargetNeverMusic() {
        XCTAssertNil(AppDelegate.resumeTarget(enabled: true, lastPlaying: "com.apple.Music", isRunning: { _ in true }))
    }
}

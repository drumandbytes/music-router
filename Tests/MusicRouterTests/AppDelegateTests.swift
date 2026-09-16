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
}

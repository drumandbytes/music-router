import XCTest
@testable import MusicRouter

final class AudioActivityTests: XCTestCase {
    // value depends on the machine; this only guards the CoreAudio plumbing
    func testProbeReturnsWithoutCrashing() {
        _ = AudioActivity.isOutputRunning()
    }
}

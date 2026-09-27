import XCTest
@testable import MusicRouter

final class MediaKeyTapTests: XCTestCase {
    /// Packs `data1` like a real NSSystemDefined event: keyCode in the top 16
    /// bits, 0xA/0xB pressed/released in the flags byte.
    private func packed(keyCode: Int, pressed: Bool) -> Int {
        let flags = pressed ? 0xA00 : 0xB00
        return (keyCode << 16) | flags
    }

    func testDecodePlayPausePressed() {
        let result = MediaKeyTap.decode(data1: packed(keyCode: 16, pressed: true))
        XCTAssertEqual(result?.0, .playPause)
        XCTAssertEqual(result?.isPressed, true)
    }

    func testDecodePlayPauseReleased() {
        let result = MediaKeyTap.decode(data1: packed(keyCode: 16, pressed: false))
        XCTAssertEqual(result?.0, .playPause)
        XCTAssertEqual(result?.isPressed, false)
    }

    func testDecodeNext() {
        let result = MediaKeyTap.decode(data1: packed(keyCode: 17, pressed: true))
        XCTAssertEqual(result?.0, .next)
    }

    func testDecodePrevious() {
        let result = MediaKeyTap.decode(data1: packed(keyCode: 18, pressed: true))
        XCTAssertEqual(result?.0, .previous)
    }

    func testDecodeUnknownKeyCodeReturnsNil() {
        let result = MediaKeyTap.decode(data1: packed(keyCode: 99, pressed: true))
        XCTAssertNil(result)
    }
}

import XCTest
@testable import MusicRouter

final class MenuItemIconTests: XCTestCase {
    /// 0 automatic, 1 visible, 2 hidden; `nil` before macOS 27.
    private func visibility(_ item: NSMenuItem) -> Int? {
        item.responds(to: NSSelectorFromString("preferredImageVisibility"))
            ? item.value(forKey: "preferredImageVisibility") as? Int
            : nil
    }

    func testSetIconKeepsImageVisibleWhereTheOSHasTheProperty() throws {
        let item = NSMenuItem(title: "x", action: nil, keyEquivalent: "")
        let image = try XCTUnwrap(NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil))
        item.setIcon(image)
        XCTAssertNotNil(item.image)
        if let raw = visibility(item) {
            XCTAssertEqual(raw, 1, "NSMenuItemImageVisibilityVisible")
        }
    }

    func testSetIconNilLeavesVisibilityAlone() {
        let item = NSMenuItem(title: "x", action: nil, keyEquivalent: "")
        item.setIcon(nil)
        XCTAssertNil(item.image)
        if let raw = visibility(item) {
            XCTAssertEqual(raw, 0, "automatic by default")
        }
    }
}

import XCTest
@testable import MusicRouter

final class MenuItemIconTests: XCTestCase {
    func testSetIconKeepsImageVisibleWhereTheOSHasTheProperty() throws {
        let item = NSMenuItem(title: "x", action: nil, keyEquivalent: "")
        let image = try XCTUnwrap(NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil))
        item.setIcon(image)
        XCTAssertNotNil(item.image)
        if let raw = item.iconVisibilityRawValue {
            XCTAssertEqual(raw, 1, "NSMenuItemImageVisibilityVisible")
        }
    }

    func testSetIconNilLeavesVisibilityAlone() {
        let item = NSMenuItem(title: "x", action: nil, keyEquivalent: "")
        item.setIcon(nil)
        XCTAssertNil(item.image)
        if let raw = item.iconVisibilityRawValue {
            XCTAssertEqual(raw, 0, "automatic by default")
        }
    }
}

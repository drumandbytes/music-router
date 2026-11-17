import Carbon.HIToolbox
import XCTest
@testable import MusicRouter

final class ShortcutTests: XCTestCase {
    private let keys = ["cycleShortcutKeyCode", "cycleShortcutModifiers", "cycleShortcutKey"]

    override func tearDown() {
        keys.forEach(UserDefaults.standard.removeObject(forKey:))
        super.tearDown()
    }

    func testDefaultDisplaysAsBefore() {
        XCTAssertEqual(Shortcut.defaultCycle.display, "⌃⌥⌘M")
        XCTAssertTrue(Shortcut.defaultCycle.isValid)
    }

    func testDisplayOrdersModifiersLikeMacOS() {
        let all = Shortcut(keyCode: 0, modifiers: UInt32(cmdKey | shiftKey | optionKey | controlKey), key: "A")
        XCTAssertEqual(all.display, "⌃⌥⇧⌘A")
    }

    func testNeedsCommandOptionOrControl() {
        XCTAssertFalse(Shortcut(keyCode: 0, modifiers: 0, key: "A").isValid)
        XCTAssertFalse(Shortcut(keyCode: 0, modifiers: UInt32(shiftKey), key: "A").isValid)
        XCTAssertTrue(Shortcut(keyCode: 0, modifiers: UInt32(optionKey), key: "A").isValid)
    }

    func testCarbonModifierConversion() {
        XCTAssertEqual(Shortcut.carbonModifiers([.command, .option]), UInt32(cmdKey | optionKey))
        XCTAssertEqual(Shortcut.carbonModifiers([.shift, .control]), UInt32(shiftKey | controlKey))
        XCTAssertEqual(Shortcut.carbonModifiers([.capsLock]), 0)
    }

    func testLabels() {
        XCTAssertEqual(Shortcut.label(keyCode: kVK_ANSI_M, characters: "m"), "M")
        XCTAssertEqual(Shortcut.label(keyCode: kVK_Space, characters: " "), "Space")
        XCTAssertEqual(Shortcut.label(keyCode: kVK_F5, characters: "\u{F708}"), "F5")
        XCTAssertEqual(Shortcut.label(keyCode: 200, characters: nil), "Key 200")
    }

    func testEventWithoutModifierIsRejected() throws {
        let bare = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
            context: nil, characters: "k", charactersIgnoringModifiers: "k", isARepeat: false, keyCode: UInt16(kVK_ANSI_K)))
        XCTAssertNil(Shortcut(event: bare))
        let chord = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [.control, .option], timestamp: 0, windowNumber: 0,
            context: nil, characters: "k", charactersIgnoringModifiers: "k", isARepeat: false, keyCode: UInt16(kVK_ANSI_K)))
        XCTAssertEqual(Shortcut(event: chord)?.display, "⌃⌥K")
    }

    func testConfigDefaultsRoundTripAndReset() {
        XCTAssertEqual(Config.cycleShortcutBinding, .defaultCycle)
        let custom = Shortcut(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(controlKey | optionKey), key: "K")
        Config.cycleShortcutBinding = custom
        XCTAssertEqual(Config.cycleShortcutBinding, custom)
        Config.cycleShortcutBinding = .defaultCycle
        XCTAssertEqual(Config.cycleShortcutBinding, .defaultCycle)
        XCTAssertNil(UserDefaults.standard.object(forKey: "cycleShortcutKeyCode"), "default is stored as absence")
    }

    func testInvalidStoredShortcutFallsBackToDefault() {
        UserDefaults.standard.set(Int(kVK_ANSI_K), forKey: "cycleShortcutKeyCode")
        UserDefaults.standard.set(0, forKey: "cycleShortcutModifiers") // no modifier
        UserDefaults.standard.set("K", forKey: "cycleShortcutKey")
        XCTAssertEqual(Config.cycleShortcutBinding, .defaultCycle)
    }

    func testPartialStoredShortcutFallsBackToDefault() {
        UserDefaults.standard.set(Int(kVK_ANSI_K), forKey: "cycleShortcutKeyCode")
        XCTAssertEqual(Config.cycleShortcutBinding, .defaultCycle)
    }
}

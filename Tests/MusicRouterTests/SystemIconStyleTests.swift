import XCTest
@testable import MusicRouter

final class SystemIconStyleTests: XCTestCase {
    func testParsesThemeNames() {
        XCTAssertEqual(SystemIconStyle.parse("RegularAutomatic"), .init(kind: .regular, forcedDark: nil))
        XCTAssertEqual(SystemIconStyle.parse("ClearAutomatic"), .init(kind: .clear, forcedDark: nil))
        XCTAssertEqual(SystemIconStyle.parse("ClearDark"), .init(kind: .clear, forcedDark: true))
        XCTAssertEqual(SystemIconStyle.parse("TintedLight"), .init(kind: .tinted, forcedDark: false))
    }

    func testUnknownOrMissingFallsBackToRegular() {
        XCTAssertEqual(SystemIconStyle.parse(nil), .default)
        XCTAssertEqual(SystemIconStyle.parse("Whatever"), .init(kind: .regular, forcedDark: nil))
    }

    func testForcedAppearanceBeatsColorScheme() {
        XCTAssertTrue(SystemIconStyle.parse("RegularDark").isDark(colorScheme: .light))
        XCTAssertFalse(SystemIconStyle.parse("RegularLight").isDark(colorScheme: .dark))
        XCTAssertTrue(SystemIconStyle.parse("RegularAutomatic").isDark(colorScheme: .dark))
    }
}

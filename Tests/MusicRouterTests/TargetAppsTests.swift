import XCTest
@testable import MusicRouter

final class TargetAppsTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "targetApp")
        UserDefaults.standard.removeObject(forKey: "cycleShortcut")
        UserDefaults.standard.removeObject(forKey: "showTargetToast")
        super.tearDown()
    }

    func testCycleGoesAutomaticThroughRunningAndBack() {
        let running = ["com.spotify.client", "org.videolan.vlc"]
        XCTAssertEqual(TargetApps.nextTarget(after: nil, running: running), "com.spotify.client")
        XCTAssertEqual(TargetApps.nextTarget(after: "com.spotify.client", running: running), "org.videolan.vlc")
        XCTAssertNil(TargetApps.nextTarget(after: "org.videolan.vlc", running: running))
    }

    func testCycleWithNothingRunningStaysAutomatic() {
        XCTAssertNil(TargetApps.nextTarget(after: nil, running: []))
        XCTAssertNil(TargetApps.nextTarget(after: "com.spotify.client", running: []))
    }

    func testCycleFromNotRunningTargetRestartsAtFirstRunning() {
        XCTAssertEqual(TargetApps.nextTarget(after: "org.videolan.vlc", running: ["com.spotify.client"]),
                       "com.spotify.client")
    }

    func testKnownBundleIDsAreUniqueAndNeverMusic() {
        let ids = TargetApps.known.map(\.bundleID)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertFalse(ids.contains { MusicLauncherGuard.shouldBlock(bundleID: $0) })
    }

    func testNameFallsBackToBundleID() {
        XCTAssertEqual(TargetApps.name(for: "com.spotify.client"), "Spotify")
        XCTAssertEqual(TargetApps.name(for: "does.not.exist.app"), "does.not.exist.app")
    }

    func testTargetConfigRoundTripAndDefaults() {
        XCTAssertNil(Config.targetApp)
        XCTAssertFalse(Config.cycleShortcut)
        Config.targetApp = "com.spotify.client"
        XCTAssertEqual(Config.targetApp, "com.spotify.client")
        Config.targetApp = nil
        XCTAssertNil(Config.targetApp)
    }

    func testDriveTargetOnlyWhenScriptable() {
        XCTAssertEqual(AppDelegate.driveTarget(selected: "a.b", isScriptable: { _ in true }), "a.b")
        XCTAssertNil(AppDelegate.driveTarget(selected: "a.b", isScriptable: { _ in false }))
        XCTAssertNil(AppDelegate.driveTarget(selected: nil, isScriptable: { _ in true }))
    }

    func testToastMessage() {
        XCTAssertEqual(Toast.targetMessage(name: "Spotify"), "Media keys → Spotify")
        XCTAssertEqual(Toast.targetMessage(name: nil), "Media keys → Automatic")
    }

    func testToastDefaultsOnAndPersistsOff() {
        XCTAssertTrue(Config.showTargetToast)
        Config.showTargetToast = false
        XCTAssertFalse(Config.showTargetToast)
    }
}

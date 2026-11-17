import XCTest

/// `scripts/musicrouter-media` in dry-run mode: checks the command mapping
/// without touching MediaRemote.
final class MediaCLITests: XCTestCase {
    private let script = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("scripts/musicrouter-media").path

    private func run(_ args: [String]) throws -> (status: Int32, out: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [script] + args
        task.environment = ["MUSICROUTER_MEDIA_DRYRUN": "1", "PATH": "/usr/bin:/bin"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        try task.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return (task.terminationStatus, String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func testCommandMapping() throws {
        XCTAssertEqual(try run(["toggle"]).out, "send 2")
        XCTAssertEqual(try run(["toggle-play-pause"]).out, "send 2")
        XCTAssertEqual(try run(["play"]).out, "send 0")
        XCTAssertEqual(try run(["pause"]).out, "send 1")
        XCTAssertEqual(try run(["next"]).out, "send 4")
        XCTAssertEqual(try run(["previous-track"]).out, "send 5")
    }

    func testStreamAndGetDefaults() throws {
        XCTAssertEqual(try run(["stream"]).out, "stream --no-diff --no-artwork")
        XCTAssertEqual(try run(["get"]).out, "get --no-artwork")
    }

    func testUnknownCommandAndNoArgsFail() throws {
        XCTAssertEqual(try run(["bogus"]).status, 2)
        XCTAssertEqual(try run([]).status, 2)
    }
}

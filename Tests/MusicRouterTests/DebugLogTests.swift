import XCTest
@testable import MusicRouter

final class DebugLogTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func makeLog(maxBytes: Int = 2_000_000, enabled: @escaping () -> Bool = { true }) -> DebugLog {
        DebugLog(url: dir.appendingPathComponent("test.log"), maxBytes: maxBytes, isEnabled: enabled)
    }

    private func lines(_ url: URL) -> [String] {
        ((try? String(contentsOf: url, encoding: .utf8)) ?? "")
            .split(separator: "\n").map(String.init)
    }

    func testDisabledWritesNothingAndSkipsMessage() {
        var built = false
        let log = makeLog(enabled: { false })
        log.log({ built = true; return "x" }())
        log.flush()
        XCTAssertFalse(built)
        XCTAssertFalse(FileManager.default.fileExists(atPath: log.url.path))
    }

    func testWritesTimestampedLinesInOrder() {
        let log = makeLog()
        log.log("one")
        log.log("two")
        log.flush()
        let out = lines(log.url)
        XCTAssertEqual(out.count, 2)
        XCTAssertTrue(out[0].hasSuffix(" one"))
        XCTAssertTrue(out[1].hasSuffix(" two"))
        XCTAssertNotNil(out[0].range(of: #"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3} "#, options: .regularExpression))
    }

    func testRotatesAtMaxBytesKeepingOneOldFile() {
        let log = makeLog(maxBytes: 200)
        for i in 0..<20 { log.log("line number \(i) padding padding") }
        log.flush()
        XCTAssertTrue(FileManager.default.fileExists(atPath: log.rotatedURL.path))
        XCTAssertTrue(lines(log.url).last!.hasSuffix("line number 19 padding padding"))
        XCTAssertLessThan(try! Data(contentsOf: log.url).count, 400)
    }

    func testCollapsesRepeatsOnlyWhenAsked() {
        let log = makeLog()
        for _ in 0..<3 { log.log("tap", collapseRepeats: false) }
        for _ in 0..<5 { log.log("dead", collapseRepeats: true) }
        log.log("alive")
        log.flush()
        let out = lines(log.url)
        XCTAssertEqual(out.filter { $0.hasSuffix(" tap") }.count, 3)
        XCTAssertEqual(out.filter { $0.hasSuffix(" dead") }.count, 1)
        XCTAssertTrue(out.contains { $0.hasSuffix("(previous message repeated 4 more times)") })
        XCTAssertTrue(out.last!.hasSuffix(" alive"))
    }
}

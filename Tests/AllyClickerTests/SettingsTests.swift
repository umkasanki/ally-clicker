import XCTest
@testable import AllyClickerCore

final class SettingsTests: XCTestCase {

    func testDefaultsMatchPNCValues() {
        let s = Settings()
        XCTAssertEqual(s.timing.dwellTimeMs, 320)
        XCTAssertEqual(s.timing.dwellTimeMouseMs, 195)
        XCTAssertEqual(s.stillness.sensitivity, 1)
        XCTAssertTrue(s.clicks.defaultLeft)
        XCTAssertTrue(s.clicks.autoCancel)
    }

    func testSecondsConversion() {
        let t = Settings.Timing()
        XCTAssertEqual(t.dwellTimeSeconds, 0.320, accuracy: 0.0001)
        XCTAssertEqual(t.dwellTimeMouseSeconds, 0.195, accuracy: 0.0001)
        XCTAssertEqual(t.autoSelectUpSeconds, 0.210, accuracy: 0.0001)
    }

    func testJSONRoundTrip() throws {
        var s = Settings()
        s.timing.dwellTimeMs = 500
        s.clicks.defaultLeft = false
        s.stillness.sensitivity = 4

        let data = try s.jsonData()
        let decoded = try Settings.load(from: data)

        XCTAssertEqual(decoded, s)
        XCTAssertEqual(decoded.timing.dwellTimeMs, 500)
        XCTAssertEqual(decoded.clicks.defaultLeft, false)
        XCTAssertEqual(decoded.stillness.sensitivity, 4)
    }

    func testEmptyJSONDecodesToAllDefaults() throws {
        let data = "{}".data(using: .utf8)!
        let decoded = try Settings.load(from: data)
        XCTAssertEqual(decoded, Settings())
    }

    func testPartialJSONKeepsKnownValuesAndDefaultsTheRest() throws {
        // Only one nested field provided — simulates an old config missing newer keys.
        let json = """
        { "timing": { "dwellTimeMs": 600 } }
        """.data(using: .utf8)!
        let decoded = try Settings.load(from: json)

        XCTAssertEqual(decoded.timing.dwellTimeMs, 600, "Provided value is kept")
        // Everything not present falls back to defaults — not wiped.
        XCTAssertEqual(decoded.timing.dwellTimeMouseMs, Settings().timing.dwellTimeMouseMs)
        XCTAssertEqual(decoded.stillness, Settings().stillness)
        XCTAssertEqual(decoded.clicks, Settings().clicks)
        XCTAssertEqual(decoded.autoScroll, Settings().autoScroll)
    }

    func testMissingNestedFieldDoesNotResetSibling() throws {
        // clicks present but missing newer "doubleClick" key → keep others, default it.
        let json = """
        { "clicks": { "left": false, "right": false } }
        """.data(using: .utf8)!
        let decoded = try Settings.load(from: json)

        XCTAssertFalse(decoded.clicks.left)
        XCTAssertFalse(decoded.clicks.right)
        XCTAssertTrue(decoded.clicks.doubleClick, "Absent field defaults, siblings preserved")
        XCTAssertTrue(decoded.clicks.defaultLeft)
    }
}

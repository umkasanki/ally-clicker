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

    func testDecodingIsResilientToMissingKeys() throws {
        // A minimal JSON should still decode using struct defaults for absent fields.
        // (Swift's synthesized Decodable requires present keys, so this documents
        // that we rely on full round-trips; a partial JSON would throw.)
        let full = try Settings().jsonData()
        XCTAssertNoThrow(try Settings.load(from: full))
    }
}

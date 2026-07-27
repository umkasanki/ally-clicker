import XCTest
@testable import AllyClickerCore

final class CalibrationTests: XCTestCase {

    func testDisabledFallsBackToManualDwell() {
        var s = Settings()
        s.timing.dwellTimeMouseMs = 195
        s.calibration.enabled = false
        s.calibration.averageVelocity = 0.39
        XCTAssertEqual(s.effectiveDwellMouseSeconds, 0.195, accuracy: 0.0001)
    }

    func testEnabledButNoVelocityFallsBack() {
        var s = Settings()
        s.timing.dwellTimeMouseMs = 200
        s.calibration.enabled = true
        s.calibration.averageVelocity = 0  // not measured yet
        XCTAssertEqual(s.effectiveDwellMouseSeconds, 0.200, accuracy: 0.0001)
    }

    func testFormulaMatchesPNCReference() {
        // multiplier 76, sensitivity 1, velocity 0.39 → ~194ms (≈ the user's 195).
        let cal = Settings.Calibration(enabled: true, averageVelocity: 0.39, multiplier: 76)
        XCTAssertEqual(cal.computedDwellMs(sensitivity: 1), 194)
    }

    func testSlowerMoverGetsLongerDwell() {
        let fast = Settings.Calibration(enabled: true, averageVelocity: 1.0, multiplier: 76)
        let slow = Settings.Calibration(enabled: true, averageVelocity: 0.2, multiplier: 76)
        let fastMs = fast.computedDwellMs(sensitivity: 1)!
        let slowMs = slow.computedDwellMs(sensitivity: 1)!
        XCTAssertGreaterThan(slowMs, fastMs, "Slower cursor → longer dwell (auto-adaptation)")
    }

    func testComputedDwellNeverZeroOrNegative() {
        // Extreme velocity would truncate toward 0 — must clamp to ≥ 1ms.
        let cal = Settings.Calibration(enabled: true, averageVelocity: 100000, multiplier: 1)
        XCTAssertEqual(cal.computedDwellMs(sensitivity: 1), 1)
    }

    func testEngineUsesCalibratedDwellWhenEnabled() {
        var s = Settings()
        s.calibration = Settings.Calibration(enabled: true, averageVelocity: 0.39, multiplier: 76)
        // Computed ≈ 194ms; manual is 195ms — assert the engine honors the computed value.
        var engine = DwellEngine(settings: s)
        // Arm left via panel.
        let armTicks = Int(s.timing.dwellTimeSeconds / 0.005) + 5
        for _ in 0..<armTicks { _ = engine.tick(cursor: .zero, zone: .panel(button: .left), dt: 0.005) }

        // Fire on desktop; count ticks until the fire.
        let point = Point(x: 400, y: 400)
        var ticksToFire = 0
        for i in 1...1000 {
            let e = engine.tick(cursor: point, zone: .desktop, dt: 0.001)  // 1ms ticks
            if e.contains(where: { if case .fire = $0 { return true }; return false }) { ticksToFire = i; break }
        }
        XCTAssertEqual(Double(ticksToFire), 194, accuracy: 2, "Engine fires at the calibrated ~194ms, not 195")
    }

    func testCalibrationResilientDecode() throws {
        let json = """
        { "calibration": { "enabled": true } }
        """.data(using: .utf8)!
        let decoded = try Settings.load(from: json)
        XCTAssertTrue(decoded.calibration.enabled)
        XCTAssertEqual(decoded.calibration.averageVelocity, 0, "Absent field defaults")
        XCTAssertEqual(decoded.calibration.multiplier, Settings.Calibration().multiplier)
    }
}

// Convenience init for tests.
private extension Settings.Calibration {
    init(enabled: Bool, averageVelocity: Double, multiplier: Double) {
        self.init()
        self.enabled = enabled
        self.averageVelocity = averageVelocity
        self.multiplier = multiplier
    }
}

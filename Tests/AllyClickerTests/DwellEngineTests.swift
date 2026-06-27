import XCTest
import CoreGraphics
@testable import AllyClickerCore

final class DwellEngineTests: XCTestCase {
    var engine: DwellEngine!
    let tickDt = 0.005  // 5 ms — matches Settings.stillness.trackerIntervalMs

    override func setUp() {
        engine = DwellEngine(settings: Settings())
    }

    // MARK: - Helpers

    /// Dwell on a panel button until it becomes armed. Returns true if armed.
    @discardableResult
    private func armAction(_ action: DwellEngine.Action) -> Bool {
        let threshold = engine.settings.timing.dwellTimeSeconds
        let ticks = Int(threshold / tickDt) + 5
        var armed = false
        for _ in 0..<ticks {
            let effects = engine.tick(cursor: .zero, zone: .panel(button: action), dt: tickDt)
            if effects.contains(.setArmed(action)) { armed = true }
        }
        return armed
    }

    private func hasFire(_ effects: [DwellEngine.Effect]) -> Bool {
        effects.contains { if case .fire = $0 { return true }; return false }
    }

    // MARK: - Tests

    func testPanelDwellArmsAction() {
        let armed = armAction(.left)
        XCTAssertTrue(armed)
        XCTAssertEqual(engine.armed, .left)
    }

    func testDesktopDwellFiresWhenArmed() {
        armAction(.left)

        let threshold = engine.settings.timing.dwellTimeMouseSeconds
        let ticks = Int(threshold / tickDt) + 5
        var fired = false
        let point = CGPoint(x: 100, y: 100)
        for _ in 0..<ticks {
            let effects = engine.tick(cursor: point, zone: .desktop, dt: tickDt)
            if hasFire(effects) { fired = true; break }
        }
        XCTAssertTrue(fired)
    }

    func testNoFireWhenNotArmed() {
        // armed is nil by default — desktop dwell must never fire
        var fired = false
        let point = CGPoint(x: 100, y: 100)
        for _ in 0..<200 {
            let effects = engine.tick(cursor: point, zone: .desktop, dt: 0.05)
            if hasFire(effects) { fired = true }
        }
        XCTAssertFalse(fired)
    }

    func testMovementResetsDwellTimer() {
        armAction(.left)

        // Start dwell at point A
        let a = CGPoint(x: 100, y: 100)
        let b = CGPoint(x: 200, y: 200)  // far from A — resets timer
        _ = engine.tick(cursor: a, zone: .desktop, dt: tickDt)

        // Move to B — timer resets
        _ = engine.tick(cursor: b, zone: .desktop, dt: tickDt)

        // Dwell at B for just under threshold — should not fire
        let threshold = engine.settings.timing.dwellTimeMouseSeconds
        let safeTicks = Int(threshold / tickDt) - 5
        var fired = false
        for _ in 0..<safeTicks {
            let effects = engine.tick(cursor: b, zone: .desktop, dt: tickDt)
            if hasFire(effects) { fired = true }
        }
        XCTAssertFalse(fired)
    }

    func testSwipeResetClearsArmedAction() {
        armAction(.right)
        XCTAssertNotNil(engine.armed)

        // Simulate cursor coming from desktop into panel
        _ = engine.tick(cursor: .zero, zone: .desktop, dt: tickDt)
        let effects = engine.tick(cursor: .zero, zone: .panel(button: nil), dt: tickDt)

        XCTAssertNil(engine.armed)
        XCTAssertTrue(effects.contains(.setArmed(nil)))
    }

    func testDefaultLeftAfterFire() {
        var settings = Settings()
        settings.clicks.defaultLeft = true
        engine = DwellEngine(settings: settings)

        armAction(.right)
        XCTAssertEqual(engine.armed, .right)

        // Fire on desktop
        let threshold = engine.settings.timing.dwellTimeMouseSeconds
        let ticks = Int(threshold / tickDt) + 5
        let point = CGPoint(x: 100, y: 100)
        for _ in 0..<ticks {
            _ = engine.tick(cursor: point, zone: .desktop, dt: tickDt)
        }

        XCTAssertEqual(engine.armed, .left, "Should revert to left after firing")
    }

    func testAutoCancelClearsArmedWhenDefaultLeftOff() {
        var settings = Settings()
        settings.clicks.defaultLeft = false
        settings.clicks.autoCancel = true
        engine = DwellEngine(settings: settings)

        armAction(.right)

        let threshold = engine.settings.timing.dwellTimeMouseSeconds
        let ticks = Int(threshold / tickDt) + 5
        let point = CGPoint(x: 100, y: 100)
        for _ in 0..<ticks {
            _ = engine.tick(cursor: point, zone: .desktop, dt: tickDt)
        }

        XCTAssertNil(engine.armed, "autoCancel=true, defaultLeft=false → clear after fire")
    }

    func testRepeatModeKeepsArmedAfterFire() {
        var settings = Settings()
        settings.clicks.defaultLeft = false
        settings.clicks.autoCancel = false  // repeat forever
        engine = DwellEngine(settings: settings)

        armAction(.right)

        let threshold = engine.settings.timing.dwellTimeMouseSeconds
        let ticks = Int(threshold / tickDt) + 5
        let point = CGPoint(x: 100, y: 100)
        for _ in 0..<ticks {
            _ = engine.tick(cursor: point, zone: .desktop, dt: tickDt)
        }

        XCTAssertEqual(engine.armed, .right, "autoCancel=false → stay armed with same action")
    }

    func testDwellProgressReachesOne() {
        var maxFraction = 0.0
        let threshold = engine.settings.timing.dwellTimeSeconds
        let ticks = Int(threshold / tickDt) + 5
        for _ in 0..<ticks {
            let effects = engine.tick(cursor: .zero, zone: .panel(button: .left), dt: tickDt)
            for effect in effects {
                if case .dwellProgress(_, let f) = effect { maxFraction = max(maxFraction, f) }
            }
        }
        XCTAssertEqual(maxFraction, 1.0, accuracy: 0.01)
    }
}

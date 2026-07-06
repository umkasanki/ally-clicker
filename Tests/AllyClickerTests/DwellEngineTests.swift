import XCTest

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
        let point = Point(x: 100, y: 100)
        for _ in 0..<ticks {
            let effects = engine.tick(cursor: point, zone: .desktop, dt: tickDt)
            if hasFire(effects) { fired = true; break }
        }
        XCTAssertTrue(fired)
    }

    func testNoFireWhenNotArmed() {
        // armed is nil by default — desktop dwell must never fire
        var fired = false
        let point = Point(x: 100, y: 100)
        for _ in 0..<200 {
            let effects = engine.tick(cursor: point, zone: .desktop, dt: 0.05)
            if hasFire(effects) { fired = true }
        }
        XCTAssertFalse(fired)
    }

    func testMovementResetsDwellTimer() {
        armAction(.left)

        // Start dwell at point A
        let a = Point(x: 100, y: 100)
        let b = Point(x: 200, y: 200)  // far from A — resets timer
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
        let point = Point(x: 100, y: 100)
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
        let point = Point(x: 100, y: 100)
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
        let point = Point(x: 100, y: 100)
        for _ in 0..<ticks {
            _ = engine.tick(cursor: point, zone: .desktop, dt: tickDt)
        }

        XCTAssertEqual(engine.armed, .right, "autoCancel=false → stay armed with same action")
    }

    // MARK: - Idle disarm

    func testIdleDisarmClearsArmedAfterInactivity() {
        var settings = Settings()
        settings.clicks.idleDisarmSeconds = 1   // 1s of no movement
        engine = DwellEngine(settings: settings)
        armAction(.left)
        XCTAssertEqual(engine.armed, .left)

        // Hold still on the desktop past the idle limit.
        let point = Point(x: 400, y: 400)
        var cleared = false
        for _ in 0..<Int(1.0 / tickDt) + 20 {
            let e = engine.tick(cursor: point, zone: .desktop, dt: tickDt)
            if e.contains(.setArmed(nil)) { cleared = true }
        }
        XCTAssertTrue(cleared)
        XCTAssertNil(engine.armed, "Armed action cleared after idle timeout")
    }

    func testIdleDisarmDisabledByDefault() {
        armAction(.left)  // default settings: idleDisarmSeconds == 0
        let point = Point(x: 400, y: 400)
        for _ in 0..<2000 { _ = engine.tick(cursor: point, zone: .desktop, dt: tickDt) }
        XCTAssertEqual(engine.armed, .left, "Never disarms when disabled (0)")
    }

    func testMovementResetsIdleTimer() {
        var settings = Settings()
        settings.clicks.idleDisarmSeconds = 1
        engine = DwellEngine(settings: settings)
        armAction(.left)

        // Keep moving beyond moveRadius every few ticks — idle never accumulates.
        var far = false
        for i in 0..<Int(2.0 / tickDt) {
            far.toggle()
            let p = Point(x: far ? 100 : 400, y: 400)  // jumps > moveRadius
            _ = engine.tick(cursor: p, zone: .desktop, dt: tickDt)
        }
        XCTAssertNotNil(engine.armed, "Continuous movement prevents idle disarm")
    }

    // MARK: - Re-fire gate (no machine-gunning)

    private func countFires(_ effects: [DwellEngine.Effect]) -> Int {
        effects.filter { if case .fire = $0 { return true }; return false }.count
    }

    func testParkedCursorFiresOnlyOnce() {
        armAction(.left)
        mapperDesktopFiresOnce()
    }

    private func mapperDesktopFiresOnce() {
        // Park on the desktop far longer than several dwell thresholds.
        let point = Point(x: 500, y: 500)
        var fires = 0
        for _ in 0..<400 {
            fires += countFires(engine.tick(cursor: point, zone: .desktop, dt: tickDt))
        }
        XCTAssertEqual(fires, 1, "A stationary cursor must fire exactly once, not machine-gun")
    }

    func testRefiresAfterMovingToNewTarget() {
        armAction(.left)  // defaultLeft keeps .left armed after each fire

        let a = Point(x: 300, y: 300)
        let b = Point(x: 600, y: 600)  // beyond moveRadius
        var firesA = 0, firesB = 0
        let ticks = Int(engine.settings.timing.dwellTimeMouseSeconds / tickDt) + 30

        for _ in 0..<ticks { firesA += countFires(engine.tick(cursor: a, zone: .desktop, dt: tickDt)) }
        for _ in 0..<ticks { firesB += countFires(engine.tick(cursor: b, zone: .desktop, dt: tickDt)) }

        XCTAssertEqual(firesA, 1)
        XCTAssertEqual(firesB, 1, "Moving to a new target re-enables firing")
    }

    func testNoSpuriousLeftClickAfterDrag() {
        // After a drag completes and reverts to .left, a still cursor at the drop
        // point must NOT auto-fire a left click (it hasn't moved to a new target).
        armAction(.leftDrag)
        let start = Point(x: 100, y: 100)
        let downTicks = Int(engine.settings.timing.autoSelectDownSeconds / tickDt) + 5
        for _ in 0..<downTicks { _ = engine.tick(cursor: start, zone: .desktop, dt: tickDt) }

        let end = Point(x: 400, y: 400)
        let upTicks = Int(engine.settings.timing.autoSelectUpSeconds / tickDt) + 10
        for _ in 0..<upTicks { _ = engine.tick(cursor: end, zone: .desktop, dt: tickDt) }
        XCTAssertEqual(engine.armed, .left, "Reverts to left after drag")

        // Keep resting at the drop point — must not fire.
        var fires = 0
        for _ in 0..<200 { fires += countFires(engine.tick(cursor: end, zone: .desktop, dt: tickDt)) }
        XCTAssertEqual(fires, 0, "No spurious click at the drop point")
    }

    // MARK: - Drag (two-phase)

    private func hasEffect(_ effects: [DwellEngine.Effect], _ match: (DwellEngine.Effect) -> Bool) -> Bool {
        effects.contains(where: match)
    }

    private func isDragDown(_ e: DwellEngine.Effect) -> Bool { if case .dragMouseDown = e { return true }; return false }
    private func isDragUp(_ e: DwellEngine.Effect) -> Bool { if case .dragMouseUp = e { return true }; return false }

    func testDragFullCycle() {
        armAction(.leftDrag)
        XCTAssertEqual(engine.armed, .leftDrag)

        let start = Point(x: 100, y: 100)
        // Phase 1: dwell at start → mouseDown
        let downTicks = Int(engine.settings.timing.autoSelectDownSeconds / tickDt) + 5
        var sawDown = false
        for _ in 0..<downTicks {
            let e = engine.tick(cursor: start, zone: .desktop, dt: tickDt)
            if hasEffect(e, isDragDown) { sawDown = true }
        }
        XCTAssertTrue(sawDown, "Phase 1 should emit dragMouseDown")
        XCTAssertTrue(engine.dragActive)

        // Move far enough to a new point (resets dwell), then dwell → mouseUp
        let end = Point(x: 300, y: 300)
        let upTicks = Int(engine.settings.timing.autoSelectUpSeconds / tickDt) + 10
        var sawUp = false
        for _ in 0..<upTicks {
            let e = engine.tick(cursor: end, zone: .desktop, dt: tickDt)
            if hasEffect(e, isDragUp) { sawUp = true; break }
        }
        XCTAssertTrue(sawUp, "Phase 2 should emit dragMouseUp after moving")
        XCTAssertFalse(engine.dragActive)
    }

    func testDragDoesNotReleaseWithoutMoving() {
        armAction(.leftDrag)
        let start = Point(x: 100, y: 100)

        // Dwell long enough for both phases — but never move.
        let ticks = Int((engine.settings.timing.autoSelectDownSeconds
                       + engine.settings.timing.autoSelectUpSeconds) / tickDt) + 50
        var sawUp = false
        for _ in 0..<ticks {
            let e = engine.tick(cursor: start, zone: .desktop, dt: tickDt)
            if hasEffect(e, isDragUp) { sawUp = true }
        }
        XCTAssertTrue(engine.dragActive, "Without moving, drag stays held (no zero-length release)")
        XCTAssertFalse(sawUp)
    }

    func testSwipeReleasesActiveDrag() {
        armAction(.leftDrag)
        let start = Point(x: 100, y: 100)

        // Get into the held state.
        let downTicks = Int(engine.settings.timing.autoSelectDownSeconds / tickDt) + 5
        for _ in 0..<downTicks {
            _ = engine.tick(cursor: start, zone: .desktop, dt: tickDt)
        }
        XCTAssertTrue(engine.dragActive)

        // Brush the panel — must release the held button immediately.
        let e = engine.tick(cursor: .zero, zone: .panel(button: nil), dt: tickDt)
        XCTAssertTrue(hasEffect(e, isDragUp), "Entering panel during drag must release the button")
        XCTAssertFalse(engine.dragActive)
        XCTAssertNil(engine.armed)
    }

    func testSwipeOntoButtonAlsoReleasesActiveDrag() {
        armAction(.leftDrag)
        let start = Point(x: 100, y: 100)
        let downTicks = Int(engine.settings.timing.autoSelectDownSeconds / tickDt) + 5
        for _ in 0..<downTicks { _ = engine.tick(cursor: start, zone: .desktop, dt: tickDt) }
        XCTAssertTrue(engine.dragActive)

        // Enter directly onto a panel BUTTON (not chrome) — must still release.
        let e = engine.tick(cursor: .zero, zone: .panel(button: .right), dt: tickDt)
        XCTAssertTrue(hasEffect(e, isDragUp), "Entering a panel button during drag must release too")
        XCTAssertFalse(engine.dragActive)
    }

    func testForceReleaseDrag() {
        armAction(.leftDrag)
        let start = Point(x: 100, y: 100)
        let downTicks = Int(engine.settings.timing.autoSelectDownSeconds / tickDt) + 5
        for _ in 0..<downTicks { _ = engine.tick(cursor: start, zone: .desktop, dt: tickDt) }
        XCTAssertTrue(engine.dragActive)

        XCTAssertTrue(engine.forceReleaseDrag(), "Returns true when a drag was active")
        XCTAssertFalse(engine.dragActive)
        XCTAssertFalse(engine.forceReleaseDrag(), "Returns false when nothing was held")
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

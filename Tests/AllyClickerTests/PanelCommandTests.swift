import XCTest
@testable import AllyClickerCore

/// Tests for the one-shot command buttons (ON/OFF, KEYBOARD) in the engine.
final class PanelCommandTests: XCTestCase {
    var engine: DwellEngine!
    let dt = 0.005

    override func setUp() {
        engine = DwellEngine(settings: Settings())
    }

    private func commands(_ effects: [DwellEngine.Effect]) -> [DwellEngine.Command] {
        effects.compactMap { if case .runCommand(let c) = $0 { return c }; return nil }
    }

    func testDwellOnCommandFiresOnce() {
        let ticks = Int(engine.settings.timing.dwellTimeSeconds / dt) + 200
        var fired: [DwellEngine.Command] = []
        for _ in 0..<ticks {
            fired += commands(engine.tick(cursor: .zero, zone: .panelCommand(.togglePanel), dt: dt))
        }
        XCTAssertEqual(fired, [.togglePanel], "Parked on a command button fires exactly once per visit")
    }

    func testCommandDoesNotArmAnAction() {
        let ticks = Int(engine.settings.timing.dwellTimeSeconds / dt) + 5
        for _ in 0..<ticks {
            _ = engine.tick(cursor: .zero, zone: .panelCommand(.launchKeyboard), dt: dt)
        }
        XCTAssertNil(engine.armed, "Command buttons must not arm a click action")
    }

    func testRevisitingCommandFiresAgain() {
        let ticks = Int(engine.settings.timing.dwellTimeSeconds / dt) + 5

        func dwellOnToggle() -> Int {
            var n = 0
            for _ in 0..<ticks { n += commands(engine.tick(cursor: .zero, zone: .panelCommand(.togglePanel), dt: dt)).count }
            return n
        }

        XCTAssertEqual(dwellOnToggle(), 1)
        // Leave to desktop, then come back — should fire again.
        _ = engine.tick(cursor: Point(x: 800, y: 800), zone: .desktop, dt: dt)
        XCTAssertEqual(dwellOnToggle(), 1, "Re-visiting the command button fires again")
    }

    func testCommandDoesNotFlapWhenZoneChangesUnderStillCursor() {
        // Simulate ON/OFF: dwell fires once; then the panel collapses and the
        // mapper briefly reports a different zone while the cursor stays still.
        // The command must NOT fire again (no flap).
        let at = Point(x: 50, y: 50)
        let ticks = Int(engine.settings.timing.dwellTimeSeconds / dt) + 5
        var fired: [DwellEngine.Command] = []
        for _ in 0..<ticks { fired += commands(engine.tick(cursor: at, zone: .panelCommand(.togglePanel), dt: dt)) }
        XCTAssertEqual(fired, [.togglePanel])

        // Cursor stays put; zone flickers (collapse) then returns to the button.
        fired = []
        for _ in 0..<3 { fired += commands(engine.tick(cursor: at, zone: .panel(button: nil), dt: dt)) }
        for _ in 0..<3 { fired += commands(engine.tick(cursor: at, zone: .desktop, dt: dt)) }
        for _ in 0..<ticks { fired += commands(engine.tick(cursor: at, zone: .panelCommand(.togglePanel), dt: dt)) }
        XCTAssertTrue(fired.isEmpty, "A still cursor must not re-fire the command (no panel flap)")
    }

    func testEnteringCommandButtonClearsArmedAction() {
        // Arm something on a normal button first.
        let armTicks = Int(engine.settings.timing.dwellTimeSeconds / dt) + 5
        for _ in 0..<armTicks { _ = engine.tick(cursor: .zero, zone: .panel(button: .right), dt: dt) }
        XCTAssertEqual(engine.armed, .right)

        // Coming from desktop onto a command button is a swipe — clears armed.
        _ = engine.tick(cursor: .zero, zone: .desktop, dt: dt)
        _ = engine.tick(cursor: .zero, zone: .panelCommand(.togglePanel), dt: dt)
        XCTAssertNil(engine.armed, "Entering a command button (panel) clears the armed action")
    }
}

import XCTest
@testable import AllyClickerCore

// MARK: - Mock ports

final class MockCursor: CursorSampling {
    var location: Point = .zero
}

final class MockMapper: ZoneMapping {
    var zone: DwellEngine.Zone = .desktop
    func zone(at point: Point) -> DwellEngine.Zone { zone }
}

final class MockButtons: ButtonStateReading {
    var isLeftPressed = false
}

final class MockInjector: MouseInjecting {
    var clicks: [(DwellEngine.Action, Point)] = []
    var downs: [Point] = []
    var drags: [Point] = []
    var ups: [Point] = []
    func click(_ action: DwellEngine.Action, at point: Point) { clicks.append((action, point)) }
    func mouseDown(at point: Point) { downs.append(point) }
    func mouseDragged(at point: Point) { drags.append(point) }
    func mouseUp(at point: Point) { ups.append(point) }
}

// MARK: - Tests

final class DwellControllerTests: XCTestCase {
    var cursor: MockCursor!
    var mapper: MockMapper!
    var injector: MockInjector!
    var controller: DwellController!
    let dt = 0.005

    override func setUp() {
        cursor = MockCursor()
        mapper = MockMapper()
        injector = MockInjector()
        controller = DwellController(settings: Settings(), sampler: cursor, mapper: mapper, injector: injector)
    }

    /// Arm an action by dwelling on its panel button.
    private func arm(_ action: DwellEngine.Action) {
        mapper.zone = .panel(button: action)
        cursor.location = .zero
        let ticks = Int(Settings().timing.dwellTimeSeconds / dt) + 5
        for _ in 0..<ticks { controller.advance(dt: dt) }
    }

    func testFireRoutesToInjector() {
        arm(.left)
        XCTAssertEqual(controller.armed, .left)

        // Move to desktop and dwell → click should reach the injector.
        mapper.zone = .desktop
        cursor.location = Point(x: 500, y: 400)
        let ticks = Int(Settings().timing.dwellTimeMouseSeconds / dt) + 5
        for _ in 0..<ticks { controller.advance(dt: dt) }

        XCTAssertEqual(injector.clicks.count, 1)
        XCTAssertEqual(injector.clicks.first?.0, .left)
        XCTAssertEqual(injector.clicks.first?.1, Point(x: 500, y: 400))
    }

    func testUIEffectsForwarded() {
        var armedUpdates: [DwellEngine.Action?] = []
        controller.onUIEffect = { effect in
            if case .setArmed(let a) = effect { armedUpdates.append(a) }
        }
        arm(.right)
        XCTAssertEqual(armedUpdates.last, .right)
    }

    func testDragRoutesDownAndUp() {
        var setarmed: [DwellEngine.Action?] = []
        controller.onUIEffect = { if case .setArmed(let a) = $0 { setarmed.append(a) } }

        arm(.leftDrag)
        mapper.zone = .desktop

        // Phase 1 at start point
        cursor.location = Point(x: 100, y: 100)
        let downTicks = Int(Settings().timing.autoSelectDownSeconds / dt) + 5
        for _ in 0..<downTicks { controller.advance(dt: dt) }
        XCTAssertEqual(injector.downs.count, 1)

        // Move and dwell for phase 2
        cursor.location = Point(x: 400, y: 400)
        let upTicks = Int(Settings().timing.autoSelectUpSeconds / dt) + 10
        for _ in 0..<upTicks { controller.advance(dt: dt) }
        XCTAssertEqual(injector.ups.count, 1)
        XCTAssertEqual(injector.ups.first, Point(x: 400, y: 400))
    }

    // MARK: - The button state disagreeing with us

    /// A `mouseUp` can be swallowed — the application under it dies, a modal
    /// takes the events, the system drops it. Then the button is not down, but
    /// we think it is: we go on streaming drag events at nothing, and the drag
    /// never finishes. For a user whose only input is a head tracker that is not
    /// a glitch, it is the end of the session.
    func testADragEndsWhenTheButtonTurnsOutNotToBeHeld() {
        let buttons = MockButtons()
        controller = DwellController(settings: Settings(), sampler: cursor, mapper: mapper,
                                     injector: injector, buttons: buttons)
        var lost = 0
        controller.onDragLost = { lost += 1 }

        arm(.leftDrag)
        mapper.zone = .desktop
        cursor.location = Point(x: 100, y: 100)
        buttons.isLeftPressed = true          // the press lands
        for _ in 0..<(Int(Settings().timing.autoSelectDownSeconds / dt) + 5) {
            controller.advance(dt: dt)
        }
        XCTAssertEqual(injector.downs.count, 1)

        // The up never reaches the system, and the button comes back up anyway.
        buttons.isLeftPressed = false
        injector.drags.removeAll()
        cursor.location = Point(x: 300, y: 300)
        controller.advance(dt: dt)

        XCTAssertEqual(lost, 1, "the drag is given up")
        XCTAssertTrue(injector.drags.isEmpty, "and nothing more is sent at a button nobody holds")
        XCTAssertTrue(injector.ups.isEmpty, "no release either: there is nothing to release")
    }

    /// Nothing is asked and nothing is given up when the application has no way
    /// to read the button state — the behaviour every other test here relies on.
    func testWithoutAButtonReaderTheDragIsBelieved() {
        arm(.leftDrag)
        mapper.zone = .desktop
        cursor.location = Point(x: 100, y: 100)
        for _ in 0..<(Int(Settings().timing.autoSelectDownSeconds / dt) + 5) {
            controller.advance(dt: dt)
        }
        XCTAssertEqual(injector.downs.count, 1)

        cursor.location = Point(x: 300, y: 300)
        controller.advance(dt: dt)
        XCTAssertFalse(injector.drags.isEmpty)
    }

    /// A drag to where the cursor already is tells an application nothing. At a
    /// five-millisecond tick that would be two hundred identical events a second,
    /// sent into whatever else is moving the cursor.
    func testAStillCursorSendsNoDragEvents() {
        arm(.leftDrag)
        mapper.zone = .desktop
        cursor.location = Point(x: 100, y: 100)
        for _ in 0..<(Int(Settings().timing.autoSelectDownSeconds / dt) + 5) {
            controller.advance(dt: dt)
        }
        XCTAssertEqual(injector.downs.count, 1)

        injector.drags.removeAll()
        for _ in 0..<20 { controller.advance(dt: dt) }
        XCTAssertTrue(injector.drags.isEmpty, "the head is still; there is nothing to report")

        cursor.location = Point(x: 140, y: 100)
        controller.advance(dt: dt)
        XCTAssertEqual(injector.drags, [Point(x: 140, y: 100)], "and movement is reported once")
    }

    func testNoFireWhenNothingArmed() {
        mapper.zone = .desktop
        cursor.location = Point(x: 200, y: 200)
        for _ in 0..<200 { controller.advance(dt: 0.05) }
        XCTAssertTrue(injector.clicks.isEmpty)
    }

    func testCommandRoutesToOnCommand() {
        var received: [DwellEngine.Command] = []
        controller.onCommand = { received.append($0) }

        mapper.zone = .panelCommand(.launchKeyboard)
        cursor.location = .zero
        let ticks = Int(Settings().timing.dwellTimeSeconds / dt) + 5
        for _ in 0..<ticks { controller.advance(dt: dt) }

        XCTAssertEqual(received, [.launchKeyboard])
        XCTAssertTrue(injector.clicks.isEmpty, "Commands must not inject clicks")
    }

    func testReleaseHeldButtonInjectsMouseUp() {
        // Enter a held drag.
        arm(.leftDrag)
        mapper.zone = .desktop
        cursor.location = Point(x: 100, y: 100)
        let downTicks = Int(Settings().timing.autoSelectDownSeconds / dt) + 5
        for _ in 0..<downTicks { controller.advance(dt: dt) }
        XCTAssertEqual(injector.downs.count, 1)
        XCTAssertTrue(injector.ups.isEmpty)

        // Teardown must release the held button.
        cursor.location = Point(x: 123, y: 456)
        controller.releaseHeldButton()
        XCTAssertEqual(injector.ups.count, 1)
        XCTAssertEqual(injector.ups.first, Point(x: 123, y: 456))

        // Idempotent — nothing held now.
        controller.releaseHeldButton()
        XCTAssertEqual(injector.ups.count, 1)
    }
}

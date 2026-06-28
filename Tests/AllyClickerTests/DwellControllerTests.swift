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

final class MockInjector: MouseInjecting {
    var clicks: [(DwellEngine.Action, Point)] = []
    var downs: [Point] = []
    var ups: [Point] = []
    func click(_ action: DwellEngine.Action, at point: Point) { clicks.append((action, point)) }
    func mouseDown(at point: Point) { downs.append(point) }
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

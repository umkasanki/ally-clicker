import XCTest
@testable import AllyClickerCore

final class AutoScrollEngineTests: XCTestCase {
    let anchor = Point(x: 500, y: 500)
    var engine = AutoScrollEngine()

    func testDeadZoneProducesNoScroll() {
        // Within deadZonePx (10) of the anchor → zero.
        let d = engine.delta(anchor: anchor, cursor: Point(x: 505, y: 508))
        XCTAssertEqual(d.dx, 0)
        XCTAssertEqual(d.dy, 0)
    }

    func testScrollDownIsPositive() {
        let d = engine.delta(anchor: anchor, cursor: Point(x: 500, y: 600))
        XCTAssertEqual(d.dx, 0)
        XCTAssertGreaterThan(d.dy, 0)
    }

    func testScrollUpIsNegative() {
        let d = engine.delta(anchor: anchor, cursor: Point(x: 500, y: 400))
        XCTAssertLessThan(d.dy, 0)
    }

    func testFartherIsFaster() {
        let near = engine.delta(anchor: anchor, cursor: Point(x: 500, y: 540)).dy
        let far  = engine.delta(anchor: anchor, cursor: Point(x: 500, y: 700)).dy
        XCTAssertGreaterThan(far, near)
    }

    func testSpeedIsClamped() {
        let d = engine.delta(anchor: anchor, cursor: Point(x: 500, y: 50000))
        XCTAssertLessThanOrEqual(d.dy, engine.config.maxSpeedPerTick)
    }

    func testDiagonalScrollsBothAxes() {
        let d = engine.delta(anchor: anchor, cursor: Point(x: 700, y: 700))
        XCTAssertGreaterThan(d.dx, 0)
        XCTAssertGreaterThan(d.dy, 0)
    }
}

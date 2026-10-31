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

    func testIntensityNeverExceedsMaxSpeed() {
        var cfg = Settings.AutoScroll(); cfg.intensity = 5.0
        let d = AutoScrollEngine(config: cfg)
            .delta(anchor: anchor, cursor: Point(x: 500, y: 50000)).dy
        XCTAssertLessThanOrEqual(d, cfg.maxSpeedPerTick, "Cap holds regardless of intensity")
    }

    func testIntensityScalesSpeed() {
        var cfg = Settings.AutoScroll(); cfg.intensity = 1.0
        let base = AutoScrollEngine(config: cfg)
            .delta(anchor: anchor, cursor: Point(x: 500, y: 700)).dy

        cfg.intensity = 0.5
        let half = AutoScrollEngine(config: cfg)
            .delta(anchor: anchor, cursor: Point(x: 500, y: 700)).dy
        XCTAssertEqual(half, base * 0.5, accuracy: 0.001)

        cfg.intensity = 2.0
        let double = AutoScrollEngine(config: cfg)
            .delta(anchor: anchor, cursor: Point(x: 500, y: 700)).dy
        XCTAssertEqual(double, base * 2.0, accuracy: 0.001)
    }

    func testDiagonalScrollsBothAxes() {
        let d = engine.delta(anchor: anchor, cursor: Point(x: 700, y: 700))
        XCTAssertGreaterThan(d.dx, 0)
        XCTAssertGreaterThan(d.dy, 0)
    }

    func testDefaultAccelerationIsTheSquareRootRamp() {
        // 0.5 must reproduce the original formula exactly: base + sqrt(d - dead) * boost.
        let cfg = Settings.AutoScroll()
        let d = AutoScrollEngine(config: cfg).delta(anchor: anchor, cursor: Point(x: 500, y: 600)).dy
        let expected = (cfg.base + (100 - cfg.deadZonePx).squareRoot() * cfg.boost) * cfg.intensity
        XCTAssertEqual(d, expected, accuracy: 0.0001)
    }

    func testSteeperAccelerationIsSlowerNearAndFasterFar() {
        var gentle = Settings.AutoScroll(); gentle.intensity = 1
        var steep = gentle; steep.accelerationExponent = 1.5
        func dy(_ cfg: Settings.AutoScroll, _ offset: Double) -> Double {
            AutoScrollEngine(config: cfg).delta(anchor: anchor, cursor: Point(x: 500, y: 500 + offset)).dy
        }
        XCTAssertLessThan(dy(steep, 25), dy(gentle, 25), "near the anchor: slower, more precise")
        XCTAssertGreaterThan(dy(steep, 300), dy(gentle, 300), "far out: faster")
        let atReference = 10 + Settings.AutoScroll.accelerationReferencePx
        XCTAssertEqual(dy(steep, atReference), dy(gentle, atReference), accuracy: 0.0001)
    }

    func testAccelerationIsClampedWhenDecoded() throws {
        let json = #"{"accelerationExponent": 9}"#.data(using: .utf8)!
        let cfg = try JSONDecoder().decode(Settings.AutoScroll.self, from: json)
        XCTAssertEqual(cfg.accelerationExponent, Settings.AutoScroll.accelerationRange.upperBound)
        let old = try JSONDecoder().decode(Settings.AutoScroll.self, from: "{}".data(using: .utf8)!)
        XCTAssertEqual(old.accelerationExponent, 0.5, "settings saved before Acceleration keep the old ramp")
    }
}

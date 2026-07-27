import XCTest
@testable import AllyClickerCore

final class AutoScrollControllerTests: XCTestCase {
    var controller: AutoScrollController!

    override func setUp() {
        controller = AutoScrollController()
    }

    func testStartsInactive() {
        XCTAssertFalse(controller.isActive)
        XCTAssertNil(controller.tick(cursor: Point(x: 10, y: 10)))
    }

    func testActivateProducesDeltas() {
        controller.activate(at: Point(x: 100, y: 100))
        XCTAssertTrue(controller.isActive)
        let d = controller.tick(cursor: Point(x: 100, y: 300))
        XCTAssertNotNil(d)
        XCTAssertGreaterThan(d!.dy, 0)
    }

    func testDeactivateStopsScrolling() {
        controller.activate(at: Point(x: 100, y: 100))
        controller.deactivate()
        XCTAssertFalse(controller.isActive)
        XCTAssertNil(controller.tick(cursor: Point(x: 100, y: 300)))
    }

    func testToggle() {
        controller.toggle(at: Point(x: 50, y: 50))   // off → on
        XCTAssertTrue(controller.isActive)
        controller.toggle(at: Point(x: 50, y: 50))   // on → off
        XCTAssertFalse(controller.isActive)
    }

    func testAnchorIsTheActivationPoint() {
        controller.activate(at: Point(x: 200, y: 200))
        // Cursor exactly on anchor → within dead zone → no scroll.
        let d = controller.tick(cursor: Point(x: 200, y: 200))
        XCTAssertEqual(d?.dx, 0)
        XCTAssertEqual(d?.dy, 0)
    }
}

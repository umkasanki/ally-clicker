import XCTest
@testable import AllyClickerCore

/// The panel kept starting off the right-hand edge of the screen.
///
/// Not a mystery once stated: the position is remembered, and this user's
/// desktop changes size constantly — the monitor's cable moves between two
/// machines, and three buttons switch its resolution. A position saved on a
/// 1920-wide desktop is simply not on a 1536-wide one.
final class PanelPlacementTests: XCTestCase {

    private let screen = Rect(x: 0, y: 0, width: 1536, height: 864)
    private var visible: [Rect] { [Rect(x: 0, y: 0, width: 1536, height: 864)] }
    private let panelW = 60.0, panelH = 300.0

    // MARK: - fits

    func testWhollyInsideFits() {
        XCTAssertTrue(PanelPlacement.fits(Rect(x: 100, y: 100, width: 60, height: 300),
                                          in: visible))
    }

    /// Half off the edge is not "on screen". This is the case that was shipping:
    /// the panel was visible enough to prove it existed and not enough to use.
    func testPartlyOffTheEdgeDoesNotFit() {
        XCTAssertFalse(PanelPlacement.fits(Rect(x: 1500, y: 100, width: 60, height: 300),
                                           in: visible))
    }

    func testFlushAgainstTheEdgeFits() {
        XCTAssertTrue(PanelPlacement.fits(Rect(x: 1476, y: 0, width: 60, height: 300),
                                          in: visible))
    }

    func testFitsOnTheSecondScreenOfTwo() {
        let two = [Rect(x: 0, y: 0, width: 1536, height: 864),
                   Rect(x: 1536, y: 0, width: 1920, height: 1080)]
        XCTAssertTrue(PanelPlacement.fits(Rect(x: 1600, y: 100, width: 60, height: 300), in: two))
    }

    // MARK: - the rescue

    func testRescueGoesToTheRightEdgeCentredVertically() {
        let p = PanelPlacement.rescueOrigin(horizontal: false, panelW: panelW, panelH: panelH,
                                            screenFrame: screen)
        XCTAssertEqual(p.x, 1536 - 60, accuracy: 0.001, "against the right edge")
        XCTAssertEqual(p.y, 432 - 150, accuracy: 0.001, "centred vertically")
    }

    func testRescueOfAHorizontalPanelGoesToTheTopCentre() {
        let p = PanelPlacement.rescueOrigin(horizontal: true, panelW: 300, panelH: 60,
                                            screenFrame: screen)
        XCTAssertEqual(p.x, 768 - 150, accuracy: 0.001)
        XCTAssertEqual(p.y, 864 - 60, accuracy: 0.001)
    }

    // MARK: - origin

    func testASavedPositionThatStillFitsIsHonoured() {
        let p = PanelPlacement.origin(savedX: 1000, savedY: 100, horizontal: false,
                                      panelW: panelW, panelH: panelH,
                                      screenFrame: screen, visibleFrames: visible)
        XCTAssertEqual(p.x, 1000, accuracy: 0.001)
        XCTAssertEqual(p.y, 864 - 100 - 300, accuracy: 0.001)
    }

    /// The regression this was written for: a position saved on a wider desktop.
    func testASavedPositionOffTheEdgeIsRescued() {
        let p = PanelPlacement.origin(savedX: 1850, savedY: 100, horizontal: false,
                                      panelW: panelW, panelH: panelH,
                                      screenFrame: screen, visibleFrames: visible)
        XCTAssertEqual(p.x, 1536 - 60, accuracy: 0.001, "back against the right edge")
        XCTAssertEqual(p.y, 432 - 150, accuracy: 0.001, "and centred, not at the saved Y")
    }

    /// A position saved on a taller desktop puts the panel below the bottom.
    func testASavedPositionBelowTheBottomIsRescued() {
        let p = PanelPlacement.origin(savedX: 100, savedY: 800, horizontal: false,
                                      panelW: panelW, panelH: panelH,
                                      screenFrame: screen, visibleFrames: visible)
        XCTAssertEqual(p.x, 1536 - 60, accuracy: 0.001)
    }

    func testNoSavedPositionDocksRightAtTheConfiguredOffset() {
        let p = PanelPlacement.origin(savedX: nil, savedY: 100, horizontal: false,
                                      panelW: panelW, panelH: panelH,
                                      screenFrame: screen, visibleFrames: visible)
        XCTAssertEqual(p.x, 1536 - 60, accuracy: 0.001)
        XCTAssertEqual(p.y, 864 - 100 - 300, accuracy: 0.001, "the offset is kept, not centred")
    }
}

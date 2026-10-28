import XCTest
@testable import AllyClickerCore

final class TickClockTests: XCTestCase {

    /// Nothing to measure the first tick from, so it gets the interval it was meant to have.
    func testFirstTickIsCreditedTheNominalInterval() {
        var clock = TickClock(nominal: 0.005)
        XCTAssertEqual(clock.step(now: 100), 0.005, accuracy: 1e-9)
    }

    /// The point of the type: a late tick is credited the time that really passed.
    /// Before this, a tick 40 ms late still counted as 5 ms, and a 0.2 s dwell under
    /// load took far longer than 0.2 s.
    func testLateTickIsCreditedTheRealGap() {
        var clock = TickClock(nominal: 0.005)
        _ = clock.step(now: 100)
        XCTAssertEqual(clock.step(now: 100.005), 0.005, accuracy: 1e-9)
        XCTAssertEqual(clock.step(now: 100.045), 0.040, accuracy: 1e-9)
    }

    /// A 0.2 s dwell under a loop that only manages a tick every 40 ms ends after
    /// about 0.2 s of real time, not after 40 ticks (1.6 s).
    func testDwellTakesRealTimeUnderLoad() {
        var clock = TickClock(nominal: 0.005)
        var now = 0.0, elapsed = 0.0, ticks = 0
        while elapsed < 0.2 {
            elapsed += clock.step(now: now)
            now += 0.040
            ticks += 1
        }
        XCTAssertLessThanOrEqual(ticks, 7)
    }

    /// A gap far beyond the interval — sleep, a stopped process — is capped: that
    /// was not time spent watching the cursor, and must not complete a dwell at once.
    func testLongGapIsCapped() {
        var clock = TickClock(nominal: 0.005, maxStep: 0.1)
        _ = clock.step(now: 100)
        XCTAssertEqual(clock.step(now: 160), 0.1, accuracy: 1e-9)
    }

    /// A clock reading that goes backwards credits nothing, never a negative time.
    func testBackwardsClockCreditsNothing() {
        var clock = TickClock(nominal: 0.005)
        _ = clock.step(now: 100)
        XCTAssertEqual(clock.step(now: 99), 0, accuracy: 1e-9)
    }

    /// After a reset the next tick starts over from the nominal interval, rather
    /// than counting the whole time the loop was stopped.
    func testResetStartsOver() {
        var clock = TickClock(nominal: 0.005)
        _ = clock.step(now: 100)
        clock.reset()
        XCTAssertEqual(clock.step(now: 130), 0.005, accuracy: 1e-9)
    }

    /// The cap is never below the interval itself, or every tick would be shortened.
    func testCapIsNeverBelowTheInterval() {
        let clock = TickClock(nominal: 0.016, maxStep: 0.001)
        XCTAssertEqual(clock.maxStep, 0.016, accuracy: 1e-9)
    }
}

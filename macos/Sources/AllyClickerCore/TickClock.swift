import Foundation

// MARK: - TickClock
//
// Turns the moments a timer actually fired into the time that actually passed.
//
// The dwell loop used to credit every tick with its nominal interval — 5 ms —
// whether it arrived on time or 40 ms late. Under load that stretched every wait:
// a 0.2 s AutoMouse Delay took as many ticks as fitted in 0.2 s of *idle* time,
// however long they really took to arrive (issue I2 in docs/context.md). All three
// references count real time instead: DwellClick sets an absolute fire date,
// Dave Warker's dwell.m compares against GetCurrentEventTime(), and the PNC spec
// says "Pass the real dt".
//
// One limit on that. A gap far longer than the interval — the Mac slept, the
// process was stopped — is not time we spent watching the cursor, and crediting it
// would let a dwell complete the moment the loop wakes, on a cursor nobody saw
// hold still. So a single step is capped.

public struct TickClock {
    /// What the first tick is credited with: there is no previous tick to measure from.
    public let nominal: TimeInterval
    /// The most a single tick is credited with, however long the gap behind it.
    public let maxStep: TimeInterval

    private var last: TimeInterval?

    public init(nominal: TimeInterval, maxStep: TimeInterval = 0.1) {
        self.nominal = nominal
        self.maxStep = max(nominal, maxStep)
    }

    /// The time to credit for a tick that fired at `now` (any monotonic clock, seconds).
    public mutating func step(now: TimeInterval) -> TimeInterval {
        defer { last = now }
        guard let last else { return nominal }
        // A clock that went backwards credits nothing rather than a negative.
        return min(max(now - last, 0), maxStep)
    }

    /// Forget the previous tick, so the next one is credited `nominal` again —
    /// for a loop that was stopped and is starting over.
    public mutating func reset() { last = nil }
}

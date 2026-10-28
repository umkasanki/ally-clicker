import Foundation
import AllyClickerCore

// Drives DwellController.advance(dt:) on a fixed cadence (trackerIntervalMs),
// passing the time that really passed between ticks (see TickClock) — a tick the
// system delivered late must not make every dwell longer.
// Single-threaded on the main queue — matches DwellController's threading contract
// (onUIEffect runs inline and touches AppKit).

final class DwellRunner {
    private let controller: DwellController
    private let intervalMs: Int
    private var timer: DispatchSourceTimer?
    private var clock: TickClock

    /// Asked on every tick: is something else in charge of the cursor right now?
    ///
    /// Modes that take the cursor over — auto-scroll, moving the panel — used to
    /// stop this timer and rely on a callback to start it again. That makes
    /// "running" a thing to remember, and a remembered fact can be wrong: one
    /// missed callback and the timer stays stopped for good. Nothing clicks
    /// after that, and the user cannot even quit the application, because
    /// quitting takes a click.
    ///
    /// Asking instead makes the illegal state unrepresentable: the answer is
    /// derived from the modes themselves, so when no mode is active the loop is
    /// running by construction. `DwellClick` does the same thing in
    /// `DCClickMachine.performEvent` — it tests `engine.override` at the moment
    /// of acting rather than stopping its own machinery.
    var isSuspended: (() -> Bool)?

    init(controller: DwellController, intervalMs: Int) {
        self.controller = controller
        self.intervalMs = max(1, intervalMs)
        self.clock = TickClock(nominal: Double(self.intervalMs) / 1000.0)
    }

    func start() {
        guard timer == nil else { return }   // idempotent — never run two timers
        clock.reset()
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: .milliseconds(intervalMs), leeway: .milliseconds(1))
        t.setEventHandler { [weak self] in
            guard let self else { return }
            // While a mode has the cursor, forget the clock: the time it held
            // the cursor is not time this loop spent watching it.
            if self.isSuspended?() == true { self.clock.reset(); return }
            self.controller.advance(dt: self.clock.step(now: ProcessInfo.processInfo.systemUptime))
        }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }
}

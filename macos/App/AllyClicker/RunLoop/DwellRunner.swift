import Foundation
import AllyClickerCore

// Drives DwellController.advance(dt:) on a fixed cadence (trackerIntervalMs).
// Single-threaded on the main queue — matches DwellController's threading contract
// (onUIEffect runs inline and touches AppKit).

final class DwellRunner {
    private let controller: DwellController
    private let intervalMs: Int
    private var timer: DispatchSourceTimer?

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
    }

    func start() {
        guard timer == nil else { return }   // idempotent — never run two timers
        let dt = Double(intervalMs) / 1000.0
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: .milliseconds(intervalMs), leeway: .milliseconds(1))
        t.setEventHandler { [weak self] in
            guard let self else { return }
            if self.isSuspended?() == true { return }
            self.controller.advance(dt: dt)
        }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }
}

import Foundation
import AllyClickerCore

// Drives DwellController.advance(dt:) on a fixed cadence (trackerIntervalMs).
// Single-threaded on the main queue — matches DwellController's threading contract
// (onUIEffect runs inline and touches AppKit).

final class DwellRunner {
    private let controller: DwellController
    private let intervalMs: Int
    private var timer: DispatchSourceTimer?

    init(controller: DwellController, intervalMs: Int) {
        self.controller = controller
        self.intervalMs = max(1, intervalMs)
    }

    func start() {
        let dt = Double(intervalMs) / 1000.0
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: .milliseconds(intervalMs), leeway: .milliseconds(1))
        t.setEventHandler { [weak self] in
            self?.controller.advance(dt: dt)
        }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }
}

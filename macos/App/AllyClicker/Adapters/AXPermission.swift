import ApplicationServices
import Foundation
import AllyClickerCore

// AXPermission — macOS adapter for the PermissionReading port.
//
// Asks whether this process is trusted for Accessibility, which is what decides
// whether an injected CGEvent does anything at all.

final class AXPermission: PermissionReading {

    /// The answer is cached for a second. The dwell loop asks two hundred times
    /// a second and the answer changes when somebody visits System Settings —
    /// `DwellClick` re-reads it on a housekeeping timer for the same reason,
    /// rather than on every event.
    private let refreshInterval: TimeInterval = 1.0
    private var lastChecked: Date = .distantPast
    private var cached = false

    var canInjectEvents: Bool {
        if Date().timeIntervalSince(lastChecked) >= refreshInterval {
            cached = AXIsProcessTrusted()
            lastChecked = Date()
        }
        return cached
    }
}

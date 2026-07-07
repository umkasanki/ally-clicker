import SwiftUI
import AllyClickerCore

// Holds a working copy of AllyClickerCore.Settings that the form edits. Apply commits it (persist
// + apply to the running app); Cancel discards. Value-type AllyClickerCore.Settings means SwiftUI
// can bind straight into nested fields ($model.settings.timing.dwellTimeMs).
final class SettingsModel: ObservableObject {
    @Published var settings: AllyClickerCore.Settings
    private let onApply: (AllyClickerCore.Settings) -> Void
    private let onClose: () -> Void

    init(settings: AllyClickerCore.Settings, onApply: @escaping (AllyClickerCore.Settings) -> Void, onClose: @escaping () -> Void) {
        self.settings = settings
        self.onApply = onApply
        self.onClose = onClose
    }

    func apply() { onApply(settings); onClose() }
    func cancel() { onClose() }

    /// Reset ONLY the parameters this form shows (timing, sensitivity, clicks,
    /// autoScroll) to defaults. Fields not edited here — panel layout/position,
    /// keyboard target, calibration, appearance — are preserved. Takes effect on Apply.
    func resetToDefaults() {
        let d = AllyClickerCore.Settings()
        settings.timing = d.timing
        settings.stillness = d.stillness
        settings.clicks = d.clicks
        settings.autoScroll = d.autoScroll
    }
}

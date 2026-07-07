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

    /// Reset the form's parameters to defaults, preserving panel layout/position
    /// and keyboard target (not edited in this form). Takes effect on Apply.
    func resetToDefaults() {
        var defaults = AllyClickerCore.Settings()
        defaults.panel = settings.panel
        defaults.commands = settings.commands
        settings = defaults
    }
}

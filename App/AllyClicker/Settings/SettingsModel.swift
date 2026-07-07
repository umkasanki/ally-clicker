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

    // MARK: - Panel editor

    /// ON/OFF is the panel's move handle and its only way back when collapsed —
    /// it can never be removed (also enforced by Panel.normalize as a safety net).
    func canRemove(_ item: PanelItem) -> Bool { item != .command(.togglePanel) }

    func removePanelItem(_ item: PanelItem) {
        guard canRemove(item) else { return }
        settings.panel.items.removeAll { $0 == item }
    }

    func addPanelItem(_ item: PanelItem) {
        guard !settings.panel.items.contains(item) else { return }
        settings.panel.items.append(item)
    }

    /// Move an item up (offset -1) or down (offset +1) in the on-screen order.
    func movePanelItem(_ item: PanelItem, by offset: Int) {
        guard let i = settings.panel.items.firstIndex(of: item) else { return }
        let j = i + offset
        guard settings.panel.items.indices.contains(j) else { return }
        settings.panel.items.swapAt(i, j)
    }

    /// Catalog items not currently on the panel (candidates for "Add button").
    var addablePanelItems: [PanelItem] {
        PanelItem.editorCatalog.filter { !settings.panel.items.contains($0) }
    }

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

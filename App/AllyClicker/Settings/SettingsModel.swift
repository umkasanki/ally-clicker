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
        rebuildCatalogOrder()
    }

    // Apply keeps the window open so the user can keep tuning and watch the live
    // panel update; closing is via Cancel or the window's close button.
    func apply() { onApply(settings) }
    func cancel() { onClose() }

    // MARK: - Panel editor
    //
    // The editor keeps a STABLE full ordering of every catalog button (active +
    // inactive). Toggling a button off only flips its on/off state — it stays put
    // in the list instead of jumping. The real `panel.items` is derived as the
    // enabled buttons in this order.

    @Published var panelCatalogOrder: [PanelItem] = []

    private func rebuildCatalogOrder() {
        let present = settings.panel.items
        let absent = PanelItem.editorCatalog.filter { !present.contains($0) }
        var order = present + absent
        // ON/OFF is pinned to the top of the list — always the first button when on.
        if let i = order.firstIndex(of: .command(.togglePanel)), i != 0 {
            order.remove(at: i)
            order.insert(.command(.togglePanel), at: 0)
        }
        panelCatalogOrder = order
    }

    /// ON/OFF's position is fixed (always first); it can be toggled but not moved.
    func isPinned(_ item: PanelItem) -> Bool { item == .command(.togglePanel) }

    /// Recompute `panel.items` = enabled buttons, in the editor's stable order.
    private func syncPanelItems(enabled: Set<PanelItem>) {
        settings.panel.items = panelCatalogOrder.filter { enabled.contains($0) }
    }

    /// The full catalog in stable display order. Drives the single toggle list.
    var orderedPanelCatalog: [PanelItem] { panelCatalogOrder }

    func isOnPanel(_ item: PanelItem) -> Bool { settings.panel.items.contains(item) }

    /// A button may be turned off unless it's the last one still on (an empty panel
    /// would snap back to defaults on Apply).
    func canRemove(_ item: PanelItem) -> Bool { settings.panel.items.count > 1 }

    func setOnPanel(_ item: PanelItem, _ on: Bool) {
        var enabled = Set(settings.panel.items)
        if on {
            enabled.insert(item)
        } else {
            guard canRemove(item) else { return }
            enabled.remove(item)
        }
        syncPanelItems(enabled: enabled)
    }

    /// Move a button up (offset -1) or down (offset +1) in the stable list; the
    /// derived `panel.items` order follows. ON/OFF is pinned first: it can't move,
    /// and nothing can move above it.
    func movePanelItem(_ item: PanelItem, by offset: Int) {
        guard !isPinned(item) else { return }
        guard let i = panelCatalogOrder.firstIndex(of: item) else { return }
        let j = i + offset
        guard panelCatalogOrder.indices.contains(j) else { return }
        guard !isPinned(panelCatalogOrder[j]) else { return }   // don't cross ON/OFF
        panelCatalogOrder.swapAt(i, j)
        syncPanelItems(enabled: Set(settings.panel.items))
    }

    /// Reset the parameters both tabs show (timing, sensitivity, clicks, autoScroll,
    /// panel layout, appearance) to defaults. Fields NOT edited here — the KEYBOARD
    /// target and calibration — are preserved. The panel's live position also
    /// survives (applySettings re-injects it). Takes effect on Apply.
    func resetToDefaults() {
        let d = AllyClickerCore.Settings()
        settings.timing = d.timing
        settings.stillness = d.stillness
        settings.clicks = d.clicks
        settings.autoScroll = d.autoScroll
        settings.panel = d.panel
        settings.appearance = d.appearance
        rebuildCatalogOrder()   // restore the default button set + order in the list
    }
}

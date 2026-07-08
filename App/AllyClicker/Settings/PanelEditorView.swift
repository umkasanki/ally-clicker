import SwiftUI
import AllyClickerCore

// The "Panel" tab: choose which buttons appear on the panel, in what order, plus
// panel size and transparency. Reorder / remove / add are all single-click
// operations (no drag-to-reorder) so they're reachable via dwell-clicks.
struct PanelEditorView: View {
    @ObservedObject var model: SettingsModel

    // appearance.transparency is 0–255; expose it as an opacity percentage,
    // floored at 40% so the panel can never fade to unreachable.
    private func opacityPercent(_ b: Binding<Int>) -> Binding<Double> {
        Binding(get: { (Double(b.wrappedValue) / 255 * 100).rounded() },
                set: { b.wrappedValue = Int(($0 / 100 * 255).rounded()) })
    }
    private func asDouble(_ i: Binding<Int>) -> Binding<Double> {
        Binding(get: { Double(i.wrappedValue) }, set: { i.wrappedValue = Int($0.rounded()) })
    }
    // iconScale multiplier (1.0 = 100%) shown/edited as a percentage.
    private func scalePercent(_ b: Binding<Double>) -> Binding<Double> {
        Binding(get: { (b.wrappedValue * 100).rounded() },
                set: { b.wrappedValue = $0 / 100 })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsSection(title: "Icon style") {
                    iconStyleRow
                    ValueControl(title: "Icon size", value: scalePercent($model.settings.appearance.iconScale),
                                 range: 50...150, step: 5, unit: "%",
                                 help: "Glyph size relative to the default for each button.")
                }

                SettingsSection(title: "Panel buttons",
                                intro: "Buttons appear top-to-bottom in this order. Reorder with the arrows, remove with the ✕. \"Show / hide panel\" (ON/OFF) can't be removed — it's how the panel is collapsed and moved.") {
                    let items = model.settings.panel.items
                    ForEach(Array(items.enumerated()), id: \.element) { index, item in
                        buttonRow(item, isFirst: index == 0, isLast: index == items.count - 1)
                        if index < items.count - 1 { Divider() }
                    }
                }

                let addable = model.addablePanelItems
                if !addable.isEmpty {
                    SettingsSection(title: "Add button",
                                    intro: "Buttons not currently on the panel.") {
                        ForEach(addable, id: \.self) { item in
                            addRow(item)
                        }
                    }
                }

                SettingsSection(title: "Size & look",
                                intro: "Changes apply to the live panel on Apply.") {
                    ValueControl(title: "Panel width", value: asDouble($model.settings.panel.width),
                                 range: 50...110, step: 5, unit: "px",
                                 help: "Width of the panel and its square buttons. Larger = easier to hit.")
                    ValueControl(title: "Opacity", value: opacityPercent($model.settings.appearance.transparency),
                                 range: 40...100, step: 5, unit: "%",
                                 help: "Panel transparency. Lower lets the screen behind show through.")
                }
            }
            .padding(20)
        }
    }

    // MARK: - Rows

    private var iconStyleRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 12) {
                Text("Icon style").font(.system(size: 15)).frame(width: 175, alignment: .leading)
                Picker("", selection: $model.settings.appearance.iconStyle) {
                    Text("Custom").tag(Settings.Appearance.IconStyle.custom)
                    Text("System").tag(Settings.Appearance.IconStyle.system)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            Text("Custom = the app's own glyphs; System = macOS SF Symbols.")
                .font(.system(size: 13)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func buttonRow(_ item: PanelItem, isFirst: Bool, isLast: Bool) -> some View {
        HStack(spacing: 12) {
            iconView(item)
            Text(item.displayName).font(.system(size: 15))
            Spacer()
            iconButton("chevron.up", disabled: isFirst) { model.movePanelItem(item, by: -1) }
            iconButton("chevron.down", disabled: isLast) { model.movePanelItem(item, by: 1) }
            iconButton("xmark", disabled: !model.canRemove(item)) { model.removePanelItem(item) }
        }
    }

    private func addRow(_ item: PanelItem) -> some View {
        HStack(spacing: 12) {
            iconView(item)
            Text(item.displayName).font(.system(size: 15))
            Spacer()
            Button { model.addPanelItem(item) } label: {
                Label("Add", systemImage: "plus")
            }
        }
    }

    /// The item's icon in the list, matching the chosen style (custom glyph or
    /// SF Symbol), so the editor previews what the panel will actually show.
    @ViewBuilder
    private func iconView(_ item: PanelItem) -> some View {
        Group {
            if model.settings.appearance.iconStyle == .custom, let ns = item.projectIcon {
                Image(nsImage: ns).renderingMode(.template).resizable().scaledToFit()
            } else {
                Image(systemName: item.sfSymbolName).font(.system(size: 16))
            }
        }
        .frame(width: 26, height: 22)
    }

    private func iconButton(_ symbol: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.borderless)
        .disabled(disabled)
        .opacity(disabled ? 0.25 : 1)
    }
}

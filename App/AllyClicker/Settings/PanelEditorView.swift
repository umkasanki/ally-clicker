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
                }

                SettingsSection(title: "Shape") {
                    orientationRow
                }

                SettingsSection(title: "Startup") {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("Launch collapsed").font(.system(size: 15))
                            Spacer()
                            Toggle("", isOn: $model.settings.panel.launchCollapsed)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .disabled(!model.hasOnOffButton)
                        }
                        Text(model.hasOnOffButton
                             ? "Start with only the ON/OFF button showing; expand it when needed. Takes effect on next launch."
                             : "Requires the ON/OFF button on the panel.")
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .opacity(model.hasOnOffButton ? 1 : 0.5)
                }

                SettingsSection(title: "Panel buttons",
                                intro: "Toggle a button on to show it on the panel; reorder the active ones with the arrows. Turning off \"Show / hide panel\" (ON/OFF) also drops the ability to collapse or drag the panel.") {
                    let catalog = model.orderedPanelCatalog
                    ForEach(Array(catalog.enumerated()), id: \.element) { index, item in
                        buttonRow(item)
                        if index < catalog.count - 1 { Divider() }
                    }
                }

                SettingsSection(title: "Size & look",
                                intro: "Changes apply to the live panel on Apply.") {
                    ValueControl(title: "Panel width", value: asDouble($model.settings.panel.width),
                                 range: 50...110, step: 5, unit: "pt",
                                 help: "Width of the panel and its square buttons (points). Larger = easier to hit.")
                    ValueControl(title: "Opacity", value: opacityPercent($model.settings.appearance.transparency),
                                 range: 40...100, step: 5, unit: "%",
                                 help: "Panel transparency. Lower lets the screen behind show through.")
                    ValueControl(title: "Icon size", value: scalePercent($model.settings.appearance.iconScale),
                                 range: 50...150, step: 5, unit: "%",
                                 help: "Glyph size relative to the default for each button.")
                }
            }
            .padding(20)
        }
    }

    // MARK: - Rows

    private var orientationRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 12) {
                Text("Orientation").font(.system(size: 15)).frame(width: 175, alignment: .leading)
                Picker("", selection: $model.settings.panel.orientation) {
                    Text("Vertical").tag(Settings.Panel.Orientation.vertical)
                    Text("Horizontal").tag(Settings.Panel.Orientation.horizontal)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            Text("Stack the buttons in a column or a row.")
                .font(.system(size: 13)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

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

    private func buttonRow(_ item: PanelItem) -> some View {
        let present = model.isOnPanel(item)
        let order = model.orderedPanelCatalog
        let index = order.firstIndex(of: item) ?? 0
        let pinned = model.isPinned(item)
        // Can't move a pinned item, and can't move above the pinned ON/OFF.
        let upDisabled = pinned || index == 0 || model.isPinned(order[index - 1])
        let downDisabled = pinned || index == order.count - 1
        return HStack(spacing: 12) {
            iconView(item)
            Text(item.displayName).font(.system(size: 15))
                .foregroundStyle(present ? .primary : .secondary)
            Spacer()
            iconButton("chevron.up", disabled: upDisabled) {
                model.movePanelItem(item, by: -1)
            }
            iconButton("chevron.down", disabled: downDisabled) {
                model.movePanelItem(item, by: 1)
            }
            Toggle("", isOn: Binding(get: { model.isOnPanel(item) },
                                     set: { model.setOnPanel(item, $0) }))
                .labelsHidden()
                // Can't turn off the last remaining button (panel must not be empty).
                .disabled(present && !model.canRemove(item))
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

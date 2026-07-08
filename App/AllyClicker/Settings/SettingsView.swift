import SwiftUI
import AllyClickerCore

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    // Int(ms) binding shown/edited in seconds.
    private func seconds(_ ms: Binding<Int>) -> Binding<Double> {
        Binding(get: { Double(ms.wrappedValue) / 1000 },
                set: { ms.wrappedValue = Int(($0 * 1000).rounded()) })
    }
    // Int binding as Double (for ValueControl).
    private func asDouble(_ i: Binding<Int>) -> Binding<Double> {
        Binding(get: { Double(i.wrappedValue) }, set: { i.wrappedValue = Int($0.rounded()) })
    }
    // Int(seconds) binding shown/edited in minutes.
    private func minutes(_ s: Binding<Int>) -> Binding<Double> {
        Binding(get: { Double(s.wrappedValue) / 60 },
                set: { s.wrappedValue = Int(($0 * 60).rounded()) })
    }

    private enum Tab { case behavior, panel, about }
    @State private var tab: Tab = .behavior

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $tab) {
                behaviorTab
                    .tabItem { Label("Behavior", systemImage: "slider.horizontal.3") }
                    .tag(Tab.behavior)
                PanelEditorView(model: model)
                    .tabItem { Label("Panel", systemImage: "square.grid.3x1.below.line.grid.1x2") }
                    .tag(Tab.panel)
                AboutView()
                    .tabItem { Label("About", systemImage: "info.circle") }
                    .tag(Tab.about)
            }
            .padding(.top, 8)
            // The action footer only makes sense for the editable tabs.
            if tab != .about {
                Divider()
                HStack {
                    Button("Reset to defaults") { model.resetToDefaults() }
                    Spacer()
                    Button("Cancel") { model.cancel() }.keyboardShortcut(.cancelAction)
                    Button("Apply") { model.apply() }.keyboardShortcut(.defaultAction)
                }
                .padding(12)
            }
        }
        .frame(width: 640, height: 620)
    }

    private var behaviorTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                    section("Clicking", intro: "Arm an action on the panel, then hold the cursor still over your target. When it stays put for the AutoMouse Delay, the action fires at that spot.") {
                        ValueControl(title: "AutoMouse Delay", value: seconds($model.settings.timing.dwellTimeMouseMs),
                                     range: 0.10...1.50, step: 0.01, unit: "s", decimals: 2,
                                     help: "How long to hold the cursor still on the screen before the armed action fires.")
                        ValueControl(title: "Panel button", value: seconds($model.settings.timing.dwellTimeMs),
                                     range: 0.10...1.50, step: 0.01, unit: "s", decimals: 2,
                                     help: "How long to dwell on a panel button to select it.")
                        toggleRow("Default to Left Click", $model.settings.clicks.defaultLeft,
                                  help: "After any action fires, automatically re-arm Left click.")
                        toggleRow("Automatic Cancel", $model.settings.clicks.autoCancel,
                                  help: "Clear the armed action after one execution (otherwise it repeats on each stop).")
                        ValueControl(title: "Idle-disarm", value: minutes($model.settings.clicks.idleDisarmSeconds),
                                     range: 0...15, step: 1, unit: "min",
                                     help: "Clear the armed action after this long with no cursor movement. 0 = never.")
                    }
                    section("Drag", intro: "With Drag armed, hold still at the start point until the button presses down (Drag press), move to the destination, then hold still again until it releases (Drag release). Used for dragging and selecting.") {
                        ValueControl(title: "Drag press", value: seconds($model.settings.timing.autoSelectDownMs),
                                     range: 0.10...1.50, step: 0.01, unit: "s", decimals: 2,
                                     help: "Dwell at the start point before Drag presses the mouse button down.")
                        ValueControl(title: "Drag release", value: seconds($model.settings.timing.autoSelectUpMs),
                                     range: 0.10...1.50, step: 0.01, unit: "s", decimals: 2,
                                     help: "Dwell at the end point before Drag releases the mouse button.")
                    }
                    section("Scroll & Links", intro: "The MIDDLE action does two things depending on where the cursor is. Over a link: opens it in a new tab (middle click). Over empty page area: starts auto-scroll — an anchor drops where you stopped, and the page scrolls in the direction you move the cursor away from it, the farther out the faster. Move back toward the anchor to slow down. To stop, hold the cursor still anywhere — a left click fires and scrolling ends.") {
                        ValueControl(title: "Intensity", value: $model.settings.autoScroll.intensity,
                                     range: 0.25...3.0, step: 0.25, unit: "×", decimals: 2,
                                     help: "Scroll speed multiplier. Lower = slower and easier to control; higher = faster.")
                    }
                    section("Cursor precision", intro: "How steady the cursor must be to count as \"holding still\". These apply to every action above — raise them if head-tracker tremor triggers actions too early or ends drags by accident.") {
                        ValueControl(title: "Jitter tolerance", value: asDouble($model.settings.stillness.sensitivity),
                                     range: 1...10, step: 1,
                                     help: "How much cursor tremor still counts as holding still. Higher = more forgiving for shaky control.")
                        ValueControl(title: "Move threshold", value: asDouble($model.settings.stillness.moveRadiusPx),
                                     range: 4...30, step: 1, unit: "px",
                                     help: "Minimum movement counted as a real move — resets timers and ends a drag's first phase.")
                    }
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, intro: String = "", @ViewBuilder _ content: @escaping () -> Content) -> some View {
        SettingsSection(title: title, intro: intro, content: content)
    }

    private func toggleRow(_ title: String, _ isOn: Binding<Bool>, help: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Toggle(title, isOn: isOn).font(.system(size: 15))
            Text(help)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

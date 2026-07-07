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

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    section("Timing") {
                        ValueControl(title: "AutoMouse Delay", value: seconds($model.settings.timing.dwellTimeMouseMs),
                                     range: 0.10...1.50, step: 0.05, unit: "s", decimals: 2,
                                     help: "How long to hold the cursor still on the screen before the armed action fires.")
                        ValueControl(title: "Panel button", value: seconds($model.settings.timing.dwellTimeMs),
                                     range: 0.10...1.50, step: 0.05, unit: "s", decimals: 2,
                                     help: "How long to dwell on a panel button to select it.")
                        ValueControl(title: "Drag press", value: seconds($model.settings.timing.autoSelectDownMs),
                                     range: 0.10...1.50, step: 0.05, unit: "s", decimals: 2,
                                     help: "Dwell at the start point before Drag presses the mouse button down.")
                        ValueControl(title: "Drag release", value: seconds($model.settings.timing.autoSelectUpMs),
                                     range: 0.10...1.50, step: 0.05, unit: "s", decimals: 2,
                                     help: "Dwell at the end point before Drag releases the mouse button.")
                    }
                    section("Sensitivity") {
                        ValueControl(title: "Jitter tolerance", value: asDouble($model.settings.stillness.sensitivity),
                                     range: 1...10, step: 1,
                                     help: "How much cursor tremor still counts as holding still. Higher = more forgiving for shaky control.")
                        ValueControl(title: "Move threshold", value: asDouble($model.settings.stillness.moveRadiusPx),
                                     range: 4...30, step: 1, unit: "px",
                                     help: "Minimum movement counted as a real move — resets timers and ends a drag's first phase.")
                    }
                    section("Behavior") {
                        toggleRow("Default to Left Click", $model.settings.clicks.defaultLeft,
                                  help: "After any action fires, automatically re-arm Left click.")
                        toggleRow("Automatic Cancel", $model.settings.clicks.autoCancel,
                                  help: "Clear the armed action after one execution (otherwise it repeats on each stop).")
                        ValueControl(title: "Idle-disarm", value: minutes($model.settings.clicks.idleDisarmSeconds),
                                     range: 0...15, step: 1, unit: "min",
                                     help: "Clear the armed action after this long with no cursor movement. 0 = never.")
                    }
                    section("Auto-scroll") {
                        ValueControl(title: "Intensity", value: $model.settings.autoScroll.intensity,
                                     range: 0.25...3.0, step: 0.25, unit: "×", decimals: 2,
                                     help: "Scroll speed multiplier. Lower = slower and easier to control; higher = faster.")
                    }
                }
                .padding(20)
            }
            Divider()
            HStack {
                Button("Reset to defaults") { model.resetToDefaults() }
                Spacer()
                Button("Cancel") { model.cancel() }.keyboardShortcut(.cancelAction)
                Button("Apply") { model.apply() }.keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(width: 560, height: 520)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
    }

    private func toggleRow(_ title: String, _ isOn: Binding<Bool>, help: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Toggle(title, isOn: isOn)
            Text(help)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

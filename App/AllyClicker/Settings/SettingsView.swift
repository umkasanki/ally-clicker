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
                                     range: 0.10...1.50, step: 0.05, unit: "s", decimals: 2)
                        ValueControl(title: "Panel button", value: seconds($model.settings.timing.dwellTimeMs),
                                     range: 0.10...1.50, step: 0.05, unit: "s", decimals: 2)
                        ValueControl(title: "Drag press", value: seconds($model.settings.timing.autoSelectDownMs),
                                     range: 0.10...1.50, step: 0.05, unit: "s", decimals: 2)
                        ValueControl(title: "Drag release", value: seconds($model.settings.timing.autoSelectUpMs),
                                     range: 0.10...1.50, step: 0.05, unit: "s", decimals: 2)
                    }
                    section("Sensitivity") {
                        ValueControl(title: "Jitter tolerance", value: asDouble($model.settings.stillness.sensitivity),
                                     range: 1...10, step: 1)
                        ValueControl(title: "Move threshold", value: asDouble($model.settings.stillness.moveRadiusPx),
                                     range: 4...30, step: 1, unit: "px")
                    }
                    section("Behavior") {
                        Toggle("Default to Left Click", isOn: $model.settings.clicks.defaultLeft)
                        Toggle("Automatic Cancel", isOn: $model.settings.clicks.autoCancel)
                        ValueControl(title: "Idle-disarm", value: minutes($model.settings.clicks.idleDisarmSeconds),
                                     range: 0...15, step: 1, unit: "min")
                    }
                    section("Auto-scroll") {
                        ValueControl(title: "Intensity", value: $model.settings.autoScroll.intensity,
                                     range: 0.25...3.0, step: 0.25, unit: "×", decimals: 2)
                    }
                }
                .padding(20)
            }
            Divider()
            HStack {
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
}

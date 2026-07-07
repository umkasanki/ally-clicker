import SwiftUI
import AllyClickerCore

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    // Int fields exposed as Double bindings for ValueControl.
    private func intBinding(_ keyPath: WritableKeyPath<Settings, Int>) -> Binding<Double> {
        Binding(get: { Double(model.settings[keyPath: keyPath]) },
                set: { model.settings[keyPath: keyPath] = Int($0.rounded()) })
    }
    private func doubleBinding(_ keyPath: WritableKeyPath<Settings, Double>) -> Binding<Double> {
        Binding(get: { model.settings[keyPath: keyPath] },
                set: { model.settings[keyPath: keyPath] = $0 })
    }
    // Milliseconds stored, shown in seconds.
    private func msSecondsBinding(_ keyPath: WritableKeyPath<Settings, Int>) -> Binding<Double> {
        Binding(get: { Double(model.settings[keyPath: keyPath]) / 1000 },
                set: { model.settings[keyPath: keyPath] = Int(($0 * 1000).rounded()) })
    }
    // Idle seconds shown in minutes.
    private var idleMinutes: Binding<Double> {
        Binding(get: { Double(model.settings.clicks.idleDisarmSeconds) / 60 },
                set: { model.settings.clicks.idleDisarmSeconds = Int(($0 * 60).rounded()) })
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    section("Timing") {
                        ValueControl(title: "AutoMouse Delay", value: msSecondsBinding(\.timing.dwellTimeMouseMs),
                                     range: 0.10...1.50, step: 0.05, unit: "s", decimals: 2)
                        ValueControl(title: "Panel button", value: msSecondsBinding(\.timing.dwellTimeMs),
                                     range: 0.10...1.50, step: 0.05, unit: "s", decimals: 2)
                        ValueControl(title: "Drag press", value: msSecondsBinding(\.timing.autoSelectDownMs),
                                     range: 0.10...1.50, step: 0.05, unit: "s", decimals: 2)
                        ValueControl(title: "Drag release", value: msSecondsBinding(\.timing.autoSelectUpMs),
                                     range: 0.10...1.50, step: 0.05, unit: "s", decimals: 2)
                    }
                    section("Sensitivity") {
                        ValueControl(title: "Jitter tolerance", value: intBinding(\.stillness.sensitivity),
                                     range: 1...10, step: 1)
                        ValueControl(title: "Move threshold", value: intBinding(\.stillness.moveRadiusPx),
                                     range: 4...30, step: 1, unit: "px")
                    }
                    section("Behavior") {
                        Toggle("Default to Left Click", isOn: $model.settings.clicks.defaultLeft)
                        Toggle("Automatic Cancel", isOn: $model.settings.clicks.autoCancel)
                        ValueControl(title: "Idle-disarm", value: idleMinutes,
                                     range: 0...15, step: 1, unit: "min")
                    }
                    section("Auto-scroll") {
                        ValueControl(title: "Intensity", value: doubleBinding(\.autoScroll.intensity),
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

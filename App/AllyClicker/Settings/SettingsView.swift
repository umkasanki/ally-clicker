import SwiftUI
import AllyClickerCore

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    // Milliseconds field shown/edited in seconds.
    private func seconds(_ get: @escaping () -> Int, _ set: @escaping (Int) -> Void) -> Binding<Double> {
        Binding(get: { Double(get()) / 1000 }, set: { set(Int(($0 * 1000).rounded())) })
    }
    private func int(_ get: @escaping () -> Int, _ set: @escaping (Int) -> Void) -> Binding<Double> {
        Binding(get: { Double(get()) }, set: { set(Int($0.rounded())) })
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    section("Timing") {
                        ValueControl(title: "AutoMouse Delay",
                                     value: seconds({ model.settings.timing.dwellTimeMouseMs },
                                                    { model.settings.timing.dwellTimeMouseMs = $0 }),
                                     range: 0.10...1.50, step: 0.05, unit: "s", decimals: 2)
                        ValueControl(title: "Panel button",
                                     value: seconds({ model.settings.timing.dwellTimeMs },
                                                    { model.settings.timing.dwellTimeMs = $0 }),
                                     range: 0.10...1.50, step: 0.05, unit: "s", decimals: 2)
                        ValueControl(title: "Drag press",
                                     value: seconds({ model.settings.timing.autoSelectDownMs },
                                                    { model.settings.timing.autoSelectDownMs = $0 }),
                                     range: 0.10...1.50, step: 0.05, unit: "s", decimals: 2)
                        ValueControl(title: "Drag release",
                                     value: seconds({ model.settings.timing.autoSelectUpMs },
                                                    { model.settings.timing.autoSelectUpMs = $0 }),
                                     range: 0.10...1.50, step: 0.05, unit: "s", decimals: 2)
                    }
                    section("Sensitivity") {
                        ValueControl(title: "Jitter tolerance",
                                     value: int({ model.settings.stillness.sensitivity },
                                                { model.settings.stillness.sensitivity = $0 }),
                                     range: 1...10, step: 1)
                        ValueControl(title: "Move threshold",
                                     value: int({ model.settings.stillness.moveRadiusPx },
                                                { model.settings.stillness.moveRadiusPx = $0 }),
                                     range: 4...30, step: 1, unit: "px")
                    }
                    section("Behavior") {
                        Toggle("Default to Left Click", isOn: $model.settings.clicks.defaultLeft)
                        Toggle("Automatic Cancel", isOn: $model.settings.clicks.autoCancel)
                        ValueControl(title: "Idle-disarm",
                                     value: Binding(
                                        get: { Double(model.settings.clicks.idleDisarmSeconds) / 60 },
                                        set: { model.settings.clicks.idleDisarmSeconds = Int(($0 * 60).rounded()) }),
                                     range: 0...15, step: 1, unit: "min")
                    }
                    section("Auto-scroll") {
                        ValueControl(title: "Intensity",
                                     value: $model.settings.autoScroll.intensity,
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

import SwiftUI

// Reusable numeric control with THREE synced inputs: slider (drag), −/+ buttons
// (dwell-friendly), and a keyboard field. Steps are quantized to `step`.
struct ValueControl: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var unit: String = ""
    var decimals: Int = 0

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(width: 150, alignment: .leading)
            stepButton("minus") { set(value - step) }
            // Continuous slider (no `step:` → no tick marks); set() quantizes to step.
            Slider(value: Binding(get: { value }, set: { set($0) }), in: range)
            stepButton("plus") { set(value + step) }
            TextField("", value: Binding(get: { value }, set: { set($0) }), formatter: formatter)
                .frame(width: 56)
                .multilineTextAlignment(.trailing)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)
        }
    }

    // Identical square buttons — frame the label content so both are the same size.
    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 30, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
    }

    private func set(_ v: Double) {
        let quantized = (v / step).rounded() * step
        value = min(range.upperBound, max(range.lowerBound, quantized))
    }

    private var formatter: NumberFormatter {
        let f = NumberFormatter()
        f.minimumFractionDigits = decimals
        f.maximumFractionDigits = decimals
        return f
    }
}

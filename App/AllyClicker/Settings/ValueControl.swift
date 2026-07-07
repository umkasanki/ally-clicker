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
            Button { set(value - step) } label: { Image(systemName: "minus") }
                .frame(width: 28)
            Slider(value: Binding(get: { value }, set: { set($0) }), in: range, step: step)
            Button { set(value + step) } label: { Image(systemName: "plus") }
                .frame(width: 28)
            TextField("", value: Binding(get: { value }, set: { set($0) }), formatter: formatter)
                .frame(width: 56)
                .multilineTextAlignment(.trailing)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)
        }
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

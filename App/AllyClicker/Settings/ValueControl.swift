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
    var help: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            controlRow
            if !help.isEmpty {
                Text(help)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var controlRow: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 15))
                .frame(width: 175, alignment: .leading)
            stepButton("minus") { set(value - step) }
            // Continuous slider (no `step:` → no tick marks); set() quantizes to step.
            Slider(value: Binding(get: { value }, set: { set($0) }), in: range)
            stepButton("plus") { set(value + step) }
            TextField("", value: Binding(get: { value }, set: { set($0) }), formatter: formatter)
                .font(.system(size: 15))
                .frame(width: 60)
                .multilineTextAlignment(.trailing)
            Text(unit)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)
        }
    }

    // Identical round buttons on both sides of the slider.
    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 26, height: 26)
                .contentShape(Circle())
        }
        .buttonStyle(.borderless)
        .background(Circle().fill(Color(nsColor: .controlColor)))
        .overlay(Circle().stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
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

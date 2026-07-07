import SwiftUI

// A titled GroupBox with an optional intro paragraph describing the mechanic.
// Shared by every tab of the Settings window so groups look identical.
struct SettingsSection<Content: View>: View {
    let title: String
    var intro: String = ""
    @ViewBuilder let content: () -> Content

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                if !intro.isEmpty {
                    Text(intro)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        } label: {
            Text(title).font(.system(size: 17, weight: .semibold)).padding(.bottom, 2)
        }
    }
}

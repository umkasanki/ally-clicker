import SwiftUI

// The "About" tab: app identity, version, credits, and the project link.
struct AboutView: View {
    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "Version \(short) (\(build))"
    }

    private let repoURL = URL(string: "https://github.com/umkasanki/ally-clicker")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AllyClicker").font(.system(size: 28, weight: .bold))
                    Text(version).font(.system(size: 14)).foregroundStyle(.secondary)
                }

                SettingsSection(title: "What it is") {
                    Text("A hands-free dwell-click tool for macOS: arm an action on the floating panel, hold the cursor still over your target, and it clicks for you. Built for head-tracker and other pointer-only users.")
                        .font(.system(size: 14))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                SettingsSection(title: "Credits") {
                    creditRow("Inspired by Point-N-Click by Polital Enterprises — a Windows dwell-click tool.",
                              "polital.com/pnc", "https://polital.com/pnc/")
                    creditRow("Action icon style inspired by DwellClick by Pilotmoon.",
                              "github.com/pilotmoon/DwellClick", "https://github.com/pilotmoon/DwellClick")
                    creditRow("Auto-scroll algorithm based on LinearMouse (MIT).",
                              "github.com/linearmouse/linearmouse", "https://github.com/linearmouse/linearmouse")
                }

                SettingsSection(title: "Project") {
                    Link("github.com/umkasanki/ally-clicker", destination: repoURL)
                        .font(.system(size: 14))
                }
            }
            .padding(20)
        }
    }

    private func creditRow(_ text: String, _ linkLabel: String, _ urlString: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text).font(.system(size: 14))
                .fixedSize(horizontal: false, vertical: true)
            if let url = URL(string: urlString) {
                Link(linkLabel, destination: url).font(.system(size: 13))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

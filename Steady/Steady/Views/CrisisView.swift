import SwiftUI

/// Region-aware crisis resources with the always-visible "not monitored"
/// honesty line. Mirrors the web `/crisis` page.
struct CrisisView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var region: CrisisRegion = CrisisData.regions[0]

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("You deserve support right now").serifTitle(30)
                    Text(CrisisData.notMonitoredLine)
                        .font(.subheadline).foregroundStyle(Color.ground)
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.pauseSoft, in: RoundedRectangle(cornerRadius: 18))

                    Picker("Region", selection: $region) {
                        ForEach(CrisisData.regions) { r in Text(r.name).tag(r) }
                    }.pickerStyle(.menu).tint(Color.ground)

                    Text(region.emergencyLine)
                        .font(.headline).foregroundStyle(Color.support)

                    VStack(spacing: 10) {
                        ForEach(region.resources) { res in
                            Button { open(res.href) } label: {
                                HStack {
                                    Text(res.label).font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(Color.ground)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    Image(systemName: "arrow.up.right").foregroundStyle(Color.olive)
                                }
                                .padding(16)
                                .background(Color.linen, in: RoundedRectangle(cornerRadius: 18))
                                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.ground.opacity(0.1)))
                            }.buttonStyle(.plain)
                        }
                        Button { open(CrisisData.fallback.href) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(CrisisData.fallback.label).font(.system(size: 16, weight: .medium)).foregroundStyle(Color.ground)
                                if let d = CrisisData.fallback.detail {
                                    Text(d).font(.caption).foregroundStyle(Color.olive)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Color.linen, in: RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.ground.opacity(0.1)))
                        }.buttonStyle(.plain)
                    }

                    Text("Verified \(region.lastVerified). Numbers change — if one doesn't connect, dial your local emergency number.")
                        .font(.caption).foregroundStyle(Color.olive)
                }
                .padding(20)
            }
        }
        .navigationTitle("Need help now")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func open(_ href: String) {
        guard let url = URL(string: href) else { return }
        openURL(url)
    }
}

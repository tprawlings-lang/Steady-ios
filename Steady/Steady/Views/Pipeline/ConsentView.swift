import SwiftUI

/// Informed-consent stepper — the versioned sections are served by the backend
/// (so copy + recorded version never drift). Agreeing records care_program_full
/// consent, then the router advances to the fitness screener.
struct ConsentInfoView: View {
    @Environment(Backend.self) private var backend
    @State private var info: ConsentInfo?
    @State private var agreed = false
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Informed consent").serifTitle(30)
                    if let info {
                        Text("Version \(info.version)").font(.caption).foregroundStyle(Color.olive)
                        ForEach(info.sections) { s in
                            SoftCard {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(s.title).font(.headline)
                                    Text(s.body).font(.subheadline).foregroundStyle(Color.ground.opacity(0.9))
                                }
                            }
                        }
                        Toggle(isOn: $agreed) {
                            Text("I've read and agree to the above.").font(.subheadline.weight(.medium))
                        }.tint(Color.sageDeep)
                        if let error { Text(error).font(.subheadline).foregroundStyle(Color.support) }
                        PrimaryButton(title: busy ? "Saving…" : "Agree and continue") { Task { await agree() } }
                            .disabled(!agreed || busy)
                    } else {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
                    }
                }
                .padding(24)
            }
        }
        .task { await load() }
    }

    private func load() async {
        do { info = try await backend.getConsent() }
        catch { self.error = "Could not load consent." }
    }
    private func agree() async {
        error = nil; busy = true; defer { busy = false }
        do { try await backend.grantConsent() }
        catch { self.error = (error as? LocalizedError)?.errorDescription ?? "Could not save consent." }
    }
}

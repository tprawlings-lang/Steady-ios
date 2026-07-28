import SwiftUI

/// The distinct voice/biometric consent (separate from the main care consent,
/// because voice can be biometric information under some laws). Granting enables
/// the hands-free in-session responder; withdrawing stops it immediately.
struct VoiceConsentView: View {
    @Environment(Backend.self) private var backend
    @Environment(\.dismiss) private var dismiss
    @State private var info: VoiceInfo?
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Voice, your choice").serifTitle(28)
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
                            if let error { Text(error).foregroundStyle(Color.support) }
                            if info.granted {
                                if !info.available {
                                    Text("Voice is granted, but live sessions aren't enabled on this deployment yet.")
                                        .font(.caption).foregroundStyle(Color.olive)
                                }
                                OutlineButton(title: busy ? "Updating…" : "Turn voice off", tint: .support) {
                                    Task { await set(false) }
                                }
                            } else {
                                PrimaryButton(title: busy ? "Updating…" : "Turn voice on") { Task { await set(true) } }
                                    .disabled(busy)
                                Text("You can use every part of Steady without voice. You can turn it off any time.")
                                    .font(.caption).foregroundStyle(Color.olive)
                            }
                        } else {
                            ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Voice").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .task { await load() }
    }

    private func load() async {
        do { info = try await backend.getVoiceInfo() } catch { self.error = "Couldn't load voice settings." }
    }
    private func set(_ grant: Bool) async {
        error = nil; busy = true; defer { busy = false }
        do {
            info = try await backend.setVoiceConsent(grant: grant)
            try? await backend.loadMe()   // refresh gating.liveVoiceAvailable
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Couldn't update voice settings."
        }
    }
}

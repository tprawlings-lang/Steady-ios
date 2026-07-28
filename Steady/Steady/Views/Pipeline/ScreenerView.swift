import SwiftUI

/// Program-fit screener (8 yes/no items). Items are served by the backend and
/// scored server-side. A hard-stop routes to crisis + a 24h cooldown; a
/// soft-flag (e.g. seizure) advances with audio-only defaulted.
struct ScreenerView: View {
    @Environment(Backend.self) private var backend
    @State private var info: ScreenerInfo?
    @State private var answers: [String: Bool] = [:]
    @State private var busy = false
    @State private var error: String?
    @State private var showCrisis = false

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("A few fit questions").serifTitle(30)
                    Text("These decide whether this self-guided program is safe for you to start. Honest answers route you to the right support — there are no wrong answers.")
                        .font(.subheadline).foregroundStyle(Color.olive)
                    if let info {
                        ForEach(info.items) { item in
                            SoftCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(item.text).font(.system(size: 16, weight: .medium)).foregroundStyle(Color.ground)
                                    if let note = item.note {
                                        Text(note).font(.caption).foregroundStyle(Color.olive)
                                    }
                                    HStack(spacing: 10) {
                                        ForEach([false, true], id: \.self) { val in
                                            Button { answers[item.id] = val } label: {
                                                Text(val ? "Yes" : "No")
                                                    .font(.subheadline).foregroundStyle(Color.ground)
                                                    .padding(.horizontal, 24).padding(.vertical, 9)
                                                    .background(answers[item.id] == val ? Color.clay : Color.linen, in: Capsule())
                                                    .overlay(Capsule().stroke(Color.ground.opacity(0.15)))
                                            }.buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                        if let error { Text(error).font(.subheadline).foregroundStyle(Color.support) }
                        PrimaryButton(title: busy ? "Submitting…" : "Continue") { Task { await submit() } }
                            .disabled(busy || answers.count < (info.items.count))
                    } else {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
                    }
                }
                .padding(24)
            }
        }
        .task { await load() }
        .sheet(isPresented: $showCrisis) { NavigationStack { CrisisView() } }
    }

    private func load() async {
        do { info = try await backend.getScreener() } catch { self.error = "Could not load the questions." }
    }
    private func submit() async {
        error = nil; busy = true; defer { busy = false }
        do {
            let result = try await backend.submitScreener(answers)
            if result.outcome == "hard_stop" { showCrisis = true }
            // On pass/soft_flag the pipeline router advances automatically
            // (gating.nextStep refreshed by submitScreener).
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Could not submit."
        }
    }
}

/// Shown when a hard-stop put the screener on a 24-hour cooldown.
struct ScreenerCooldownView: View {
    @Environment(Backend.self) private var backend
    @State private var showCrisis = false

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("This isn't the right fit right now").serifTitle(28)
                    SoftCard(background: Color.pauseSoft) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Based on your answers, a self-guided program isn't the safe choice today. That's the system working for you — not a rejection.")
                                .font(.subheadline).foregroundStyle(Color.ground)
                            if let h = backend.gating?.retakeInHours {
                                Text("You can retake the fit questions in about \(h) hour\(h == 1 ? "" : "s").")
                                    .font(.subheadline.weight(.medium)).foregroundStyle(Color.ground)
                            }
                        }
                    }
                    Text("If any charge was made, it's refunded automatically.")
                        .font(.caption).foregroundStyle(Color.olive)
                    Button { showCrisis = true } label: {
                        Text("See support that can help today").font(.headline).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.support, in: Capsule())
                    }.buttonStyle(.plain)
                    OutlineButton(title: "Refresh") { Task { try? await backend.loadMe() } }
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showCrisis) { NavigationStack { CrisisView() } }
    }
}

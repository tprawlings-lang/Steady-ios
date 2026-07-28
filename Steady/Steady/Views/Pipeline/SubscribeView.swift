import SwiftUI

/// Membership step — demo billing provider (7-day free trial), mirroring the
/// web's subscribe flow. Advancing calls the backend; the pipeline router then
/// moves to consent.
struct SubscribeView: View {
    @Environment(Backend.self) private var backend
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Start your free week").serifTitle(30)
                    SoftCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("$34.99 / month").font(.serifDisplay(30)).foregroundStyle(Color.ground)
                            Text("7 days free, then $34.99/month. Cancel anytime in two taps. If the fit questions screen you out after you've started, the charge is refunded automatically.")
                                .font(.subheadline).foregroundStyle(Color.olive)
                            Divider()
                            bullet("Guided EMDR-based sessions with safety rails")
                            bullet("Daily readiness check-ins")
                            bullet("Grounding tools and crisis resources, always open")
                        }
                    }
                    Text("This preview uses a demo billing provider — no real card is charged.")
                        .font(.caption).foregroundStyle(Color.olive)
                    if let error { Text(error).font(.subheadline).foregroundStyle(Color.support) }
                    PrimaryButton(title: busy ? "Starting…" : "Start free trial") { Task { await start() } }
                        .disabled(busy)
                }
                .padding(24)
            }
        }
    }

    private func bullet(_ t: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.safe).font(.footnote).padding(.top, 2)
            Text(t).font(.subheadline).foregroundStyle(Color.ground.opacity(0.9))
        }
    }

    private func start() async {
        error = nil; busy = true; defer { busy = false }
        do { _ = try await backend.subscribe() }
        catch { self.error = (error as? LocalizedError)?.errorDescription ?? "Could not start the trial." }
    }
}

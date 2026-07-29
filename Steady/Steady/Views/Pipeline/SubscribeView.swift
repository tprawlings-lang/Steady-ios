import SwiftUI

/// Membership step — demo billing provider, mirroring the web's three-tier
/// subscribe flow. Every tier starts with a free week of Premium; billing then
/// begins on the chosen tier. Advancing calls the backend; the pipeline router
/// then moves to consent.
struct SubscribeView: View {
    @Environment(Backend.self) private var backend
    @State private var busy = false
    @State private var error: String?

    private struct TierOption: Identifiable {
        let id: String
        let name: String
        let tagline: String
        let price: String
        let bullets: [String]
        let highlighted: Bool
    }

    private let tiers: [TierOption] = [
        TierOption(
            id: "base", name: "Base", tagline: "A calmer daily practice", price: "$6.99 / month",
            bullets: [
                "Daily check-ins that pace your day",
                "Breathe, meditate, move, and sleep practices",
                "Short lessons, grounding tools, and SOS",
                "Your companion, once a week",
            ],
            highlighted: false),
        TierOption(
            id: "plus", name: "Plus", tagline: "A program that remembers you", price: "$19.99 / month",
            bullets: [
                "Everything in Base",
                "Guided trauma-support module program",
                "Unlimited companion, with memory you control",
                "Symptom measures and progress trends",
            ],
            highlighted: true),
        TierOption(
            id: "premium", name: "Premium", tagline: "Steady runs your program with you", price: "$34.99 / month",
            bullets: [
                "Everything in Plus",
                "Autopilot: a daily plan composed for you",
                "A companion that reaches out between sessions",
                "Live spoken sessions and priority review",
            ],
            highlighted: false),
    ]

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Start your free week").serifTitle(30)
                    Text("Every membership begins with 7 days of Premium, free — the full program, the companion, everything. After your free week, billing starts on the tier you choose. Cancel anytime.")
                        .font(.subheadline).foregroundStyle(Color.olive)

                    ForEach(tiers) { tier in
                        SoftCard(background: tier.highlighted ? Color.moss : Color.linen) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .firstTextBaseline) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(tier.name).font(.serifDisplay(24)).foregroundStyle(Color.ground)
                                        Text(tier.tagline).font(.caption).foregroundStyle(Color.olive)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(tier.price).font(.headline).foregroundStyle(Color.ground)
                                        if tier.highlighted {
                                            Text("Most members choose this").font(.caption2).foregroundStyle(Color.sageDeep)
                                        }
                                    }
                                }
                                Divider()
                                ForEach(tier.bullets, id: \.self) { bullet($0) }
                                Button {
                                    Task { await start(plan: tier.id) }
                                } label: {
                                    Text(busy ? "Starting…" : "Free Premium week — then \(tier.name)")
                                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.ground)
                                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                                        .background(Color.sage, in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .disabled(busy)
                            }
                        }
                    }

                    Text("This preview uses a demo billing provider — no real card is charged. If the fit questions screen you out after you've started, the charge is refunded automatically. Crisis support and grounding stay open regardless of membership.")
                        .font(.caption).foregroundStyle(Color.olive)
                    if let error { Text(error).font(.subheadline).foregroundStyle(Color.support) }
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

    private func start(plan: String) async {
        error = nil; busy = true; defer { busy = false }
        do { _ = try await backend.subscribe(plan: plan) }
        catch { self.error = (error as? LocalizedError)?.errorDescription ?? "Could not start the trial." }
    }
}

import SwiftUI

/// A module's overview + the entry point into a guided session.
struct ModuleDetailView: View {
    let module: TherapyModule
    @Environment(AppState.self) private var app
    @Environment(Backend.self) private var backend

    private var available: Bool { backend.serverAllows(module.id) ?? app.isModuleAvailable(module) }

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        TierBadge(tier: module.tier)
                        Spacer()
                        Text(module.durationLabel).font(.caption).foregroundStyle(Color.olive)
                    }
                    Text(module.name).serifTitle(32)
                    Text(module.objective).foregroundStyle(Color.olive)

                    SoftCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("What this session includes").font(.headline)
                            ForEach(Array(stepSummary.enumerated()), id: \.offset) { _, line in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "circle.fill").font(.system(size: 6)).foregroundStyle(Color.sage).padding(.top, 6)
                                    Text(line).font(.subheadline).foregroundStyle(Color.ground.opacity(0.9))
                                }
                            }
                        }
                    }

                    if available {
                        NavigationLink {
                            SessionPlayerView(module: module)
                        } label: {
                            Text("Start session").font(.system(size: 17, weight: .medium))
                                .foregroundStyle(Color.ground).frame(maxWidth: .infinity)
                                .padding(.vertical, 15).background(Color.sage, in: Capsule())
                        }
                    } else {
                        SoftCard(background: Color.pauseSoft) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Not available right now").font(.subheadline.weight(.semibold))
                                Text(backend.serverReason(module.id) ?? "Higher-intensity processing modules unlock only after a licensed specialist reviews your progress. Keep building skills in the open modules — that's the path there.")
                                    .font(.caption).foregroundStyle(Color.ground.opacity(0.85))
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var stepSummary: [String] {
        module.steps.map { step in
            switch step.kind {
            case .instruction: return step.title
            case .suds: return "Distress check (0–10)"
            case .bls: return "Bilateral sets — \(step.sets ?? 1) × \(step.durationSec ?? 30)s"
            case .grounding: return step.title
            case .triggerEntry: return step.title
            }
        }
    }
}

struct TierBadge: View {
    let tier: ModuleTier
    var body: some View {
        Text(tier.label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color.opacity(0.95))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(color.opacity(0.16), in: Capsule())
    }
    private var color: Color {
        switch tier {
        case .autonomous: return .safeDeep
        case .gated: return .mistDeep
        case .maintenance: return .clay
        }
    }
}

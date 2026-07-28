import SwiftUI

/// Server-driven onboarding router. It shows whichever gate the backend says is
/// next (`gating.nextStep`); each step refreshes gating on completion, so the
/// member is carried straight through signup → subscribe → consent → screener →
/// measures → profile → dashboard, matching the web pipeline exactly.
struct PipelineView: View {
    @Environment(Backend.self) private var backend

    var body: some View {
        switch backend.gating?.nextStep ?? "" {
        case "subscribe":         SubscribeView()
        case "consent":           ConsentInfoView()
        case "screener":          ScreenerView()
        case "screener_cooldown": ScreenerCooldownView()
        case "measures":          MeasuresView()
        case "profile":           ProfileFlowView()
        default:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ScreenBackground())
        }
    }
}

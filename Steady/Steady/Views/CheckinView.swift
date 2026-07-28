import SwiftUI
import SwiftData

/// Daily readiness check-in — under 90 seconds. Deterministic scoring via
/// `Checkin.evaluate` decides today's safest next step. Mirrors the web
/// `/check-in` page.
struct CheckinView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var app
    @Environment(Backend.self) private var backend

    @State private var answers = CheckinAnswers()
    @State private var result: RecommendedAction?
    @State private var showCrisis = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    if let result {
                        resultView(result)
                    } else {
                        formView
                    }
                }
            }
            .navigationTitle("Daily check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Need help now?") { showCrisis = true }
                        .foregroundStyle(Color.support)
                }
            }
            .sheet(isPresented: $showCrisis) { NavigationStack { CrisisView() } }
        }
    }

    private var formView: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Under 90 seconds. Your answers shape today's safest next step — honest answers keep sessions safe. There are no wrong answers.")
                .font(.subheadline).foregroundStyle(Color.olive)

            scale("How activated do you feel right now?", "Calm", "Extremely activated",
                  Binding(get: { Double(answers.activation) }, set: { answers.activation = Int($0) }))
            scale("How down or shut down do you feel?", "Not at all", "Completely shut down",
                  Binding(get: { Double(answers.shutdown) }, set: { answers.shutdown = Int($0) }))

            yesNo("Any urge to harm yourself or others today?",
                  Binding(get: { answers.harmUrge }, set: { answers.harmUrge = $0 }), highlight: true)
            yesNo("Do you feel safe where you are?",
                  Binding(get: { answers.feelsSafe }, set: { answers.feelsSafe = $0 }), highlight: true)

            scale("Do you feel unreal, numb, or disconnected right now?", "Fully present", "Very disconnected",
                  Binding(get: { Double(answers.dissociation) }, set: { answers.dissociation = Int($0) }))
            scale("How did you sleep?", "Terribly", "Very well",
                  Binding(get: { Double(answers.sleepQuality) }, set: { answers.sleepQuality = Int($0) }))

            yesNo("Any alcohol or drug use that could affect today's session?",
                  Binding(get: { answers.substanceFlag }, set: { answers.substanceFlag = $0 }), highlight: true)

            PrimaryButton(title: "See today's recommendation") { submit() }
        }
        .padding(20)
    }

    private func resultView(_ action: RecommendedAction) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            SoftCard(background: color(for: action).opacity(0.15)) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(action.headline).serifTitle(26)
                    Text(action.detail).foregroundStyle(Color.ground.opacity(0.9))
                }
            }
            if action == .crisis {
                Button { showCrisis = true } label: {
                    Text("Open crisis resources").font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.support, in: Capsule())
                }.buttonStyle(.plain)
            }
            OutlineButton(title: "Retake check-in") { result = nil }
            Text("Saved to your history on this device.")
                .font(.caption).foregroundStyle(Color.olive).frame(maxWidth: .infinity)
        }
        .padding(20)
    }

    private func submit() {
        let action = Checkin.evaluate(answers)
        result = action
        let rec = CheckinRecord(
            date: Date(), action: action.rawValue,
            activation: answers.activation, shutdown: answers.shutdown,
            harmUrge: answers.harmUrge, feelsSafe: answers.feelsSafe,
            dissociation: answers.dissociation, sleepQuality: answers.sleepQuality,
            substanceFlag: answers.substanceFlag, synced: false)
        context.insert(rec)
        try? context.save()

        // Push to the shared account (best-effort; stays queued if offline).
        if backend.isAuthenticated {
            let body = CheckinBody(
                activation: answers.activation, shutdown: answers.shutdown,
                harm_urge: answers.harmUrge, feels_safe: answers.feelsSafe,
                dissociation: answers.dissociation, sleep_quality: answers.sleepQuality,
                substance_flag: answers.substanceFlag)
            Task { @MainActor in
                if (try? await backend.postCheckin(body)) != nil {
                    rec.synced = true
                    try? context.save()
                }
            }
        }
        if action == .crisis { showCrisis = true }
    }

    private func color(for action: RecommendedAction) -> Color {
        switch action {
        case .crisis: return .support
        case .groundingOnly: return .pause
        case .stabilization: return .clay
        case .processingOk: return .safe
        }
    }

    private func scale(_ title: String, _ low: String, _ high: String, _ binding: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 16, weight: .medium)).foregroundStyle(Color.ground)
            Slider(value: binding, in: 0...10, step: 1).tint(Color.sage)
            HStack {
                Text(low).font(.caption).foregroundStyle(Color.olive)
                Spacer()
                Text("\(Int(binding.wrappedValue))").font(.subheadline.bold()).foregroundStyle(Color.ground)
                Spacer()
                Text(high).font(.caption).foregroundStyle(Color.olive)
            }
        }
    }

    private func yesNo(_ title: String, _ binding: Binding<Bool>, highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 16, weight: .medium)).foregroundStyle(Color.ground)
            HStack(spacing: 10) {
                ForEach([false, true], id: \.self) { val in
                    Button { binding.wrappedValue = val } label: {
                        Text(val ? "Yes" : "No")
                            .font(.subheadline).foregroundStyle(Color.ground)
                            .padding(.horizontal, 24).padding(.vertical, 9)
                            .background(binding.wrappedValue == val ? Color.clay : Color.linen, in: Capsule())
                            .overlay(Capsule().stroke(Color.ground.opacity(0.15)))
                    }.buttonStyle(.plain)
                }
            }
        }
        .padding(highlight ? 14 : 0)
        .background(highlight ? Color.linen : Color.clear, in: RoundedRectangle(cornerRadius: 18))
        .overlay(highlight ? RoundedRectangle(cornerRadius: 18).stroke(Color.ground.opacity(0.08)) : nil)
    }
}

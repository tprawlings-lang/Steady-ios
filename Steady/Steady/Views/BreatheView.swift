import SwiftUI
import CoreHaptics

/// Breathwork library + paced-breathing player (roadmap F3). Backend-served,
/// safety-ordered patterns; the pacer animates a circle and — on iPhone — fires
/// gentle Core Haptics cues at each phase. Deterministic patterns; no media.
struct BreatheView: View {
    @Environment(Backend.self) private var backend

    @State private var practices: [PracticeDTO] = []
    @State private var selected: PracticeDTO?
    @State private var running = false
    @State private var done = false
    @State private var label = ""
    @State private var scale: CGFloat = 0.5
    @State private var loadError: String?
    @State private var runTask: Task<Void, Never>?
    @State private var startedAt = Date()
    private let haptics = BreathHaptics()

    var body: some View {
        ZStack {
            ScreenBackground()
            if let selected, running || done {
                player(selected)
            } else {
                library
            }
        }
        .task { await load() }
        .onDisappear {
            running = false
            runTask?.cancel()
            haptics.stop()
        }
    }

    private func load() async {
        do { practices = try await backend.getPractices() }
        catch { loadError = "Couldn't load breathing patterns." }
    }

    // MARK: Library

    private var library: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Breathe").serifTitle(34)
                Text("A few minutes of paced breathing to settle your system — before a session, or any time. Pick one that feels right; there's no wrong choice.")
                    .foregroundStyle(Color.olive)
                if let loadError { Text(loadError).font(.footnote).foregroundStyle(Color.support) }
                ForEach(practices) { p in
                    Button { start(p) } label: {
                        SoftCard {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(p.title).font(.serifDisplay(22)).foregroundStyle(Color.ground)
                                    Spacer()
                                    Text("\(Int((p.durationSec / 60).rounded())) min\(p.hasHold ? "" : " · no holds")")
                                        .font(.caption).foregroundStyle(Color.olive)
                                }
                                Text(p.intro).font(.subheadline).foregroundStyle(Color.olive)
                            }
                        }
                    }.buttonStyle(.plain)
                }
                Text("Gentler patterns come first on days your check-in suggests taking it easy. Stop any time.")
                    .font(.caption).foregroundStyle(Color.olive).padding(.top, 4)
            }
            .padding(20)
        }
    }

    // MARK: Player

    @ViewBuilder private func player(_ p: PracticeDTO) -> some View {
        VStack(spacing: 28) {
            Spacer()
            if running {
                ZStack {
                    Circle().fill(Color.sage.opacity(0.30))
                        .frame(width: 260, height: 260)
                        .scaleEffect(scale)
                    Circle().fill(Color.sage.opacity(0.5)).frame(width: 150, height: 150)
                }
                .frame(width: 260, height: 260)
                Text(label).font(.serifDisplay(30)).foregroundStyle(Color.ground)
                if let note = p.note {
                    Text(note).font(.footnote).foregroundStyle(Color.olive)
                        .multilineTextAlignment(.center).padding(.horizontal, 24)
                }
                Spacer()
                Button { finish(p) } label: {
                    Text("I'm done").font(.headline).foregroundStyle(Color.ground)
                        .padding(.horizontal, 28).padding(.vertical, 14)
                        .overlay(Capsule().stroke(Color.ground.opacity(0.25)))
                }.buttonStyle(.plain).padding(.bottom, 24)
            } else {
                Text("Nicely done").serifTitle(30)
                Text("That's a small, real act of care. Your breath is always here to come back to.")
                    .foregroundStyle(Color.olive).multilineTextAlignment(.center).padding(.horizontal, 28)
                Spacer()
                PrimaryButton(title: "Another pattern") { reset() }
                    .padding(.horizontal, 20).padding(.bottom, 24)
            }
        }
    }

    // MARK: Runner

    private func start(_ p: PracticeDTO) {
        selected = p; done = false; running = true; startedAt = Date()
        haptics.prepare()
        runTask?.cancel()
        runTask = Task { await run(p) }
    }

    @MainActor
    private func run(_ p: PracticeDTO) async {
        let phases = p.phases ?? []
        guard !phases.isEmpty else { finish(p); return }
        var i = 0
        while running && !Task.isCancelled {
            if Date().timeIntervalSince(startedAt) >= p.durationSec { finish(p); return }
            let phase = phases[i % phases.count]
            label = phaseLabel(phase.label)
            haptics.cue(phase.label)
            if phase.label == "inhale" {
                withAnimation(.easeInOut(duration: phase.seconds)) { scale = 1.0 }
            } else if phase.label == "exhale" {
                withAnimation(.easeInOut(duration: phase.seconds)) { scale = 0.4 }
            }
            do { try await Task.sleep(nanoseconds: UInt64(phase.seconds * 1_000_000_000)) }
            catch { return }
            i += 1
        }
    }

    private func finish(_ p: PracticeDTO) {
        running = false; done = true
        runTask?.cancel(); haptics.stop()
        let elapsed = Int(Date().timeIntervalSince(startedAt))
        if elapsed >= 20 {
            Task { try? await backend.completePractice(practiceId: p.id, durationSec: elapsed) }
        }
    }

    private func reset() {
        running = false; done = false; selected = nil; scale = 0.5
    }

    private func phaseLabel(_ label: String) -> String {
        switch label {
        case "inhale": return "Breathe in"
        case "exhale": return "Breathe out"
        case "hold": return "Hold"
        default: return "Rest"
        }
    }
}

/// Gentle Core Haptics phase cues for the breath pacer (best-effort).
final class BreathHaptics {
    private var engine: CHHapticEngine?

    func prepare() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        engine?.isAutoShutdownEnabled = true
        try? engine?.start()
    }

    func cue(_ label: String) {
        guard let engine else { return }
        let intensity: Float = label == "hold" || label == "rest" ? 0.25 : 0.6
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4),
            ],
            relativeTime: 0
        )
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            try engine.start()
            try engine.makePlayer(with: pattern).start(atTime: 0)
        } catch {
            // best-effort
        }
    }

    func stop() {
        engine?.stop()
        engine = nil
    }
}

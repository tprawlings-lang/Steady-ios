import SwiftUI
import CoreHaptics

/// Shared paced-breathing player: an expanding/contracting circle synced to a
/// practice's phases, with gentle Core Haptics cues. Calls onDone(elapsedSec)
/// once (natural finish or "I'm done"). Used by the Breathe library and the
/// prepare-for-session on-ramp.
struct BreathePacerView: View {
    let practice: PracticeDTO
    let onDone: (Int) -> Void

    @State private var running = false
    @State private var ended = false
    @State private var label = ""
    @State private var scale: CGFloat = 0.5
    @State private var startedAt = Date()
    @State private var runTask: Task<Void, Never>?
    private let haptics = BreathHaptics()

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle().fill(Color.sage.opacity(0.30)).frame(width: 260, height: 260).scaleEffect(scale)
                Circle().fill(Color.sage.opacity(0.5)).frame(width: 150, height: 150)
            }
            .frame(width: 260, height: 260)
            Text(label).font(.serifDisplay(30)).foregroundStyle(Color.ground)
            if let note = practice.note {
                Text(note).font(.footnote).foregroundStyle(Color.olive)
                    .multilineTextAlignment(.center).padding(.horizontal, 24)
            }
            Button { end() } label: {
                Text("I'm done").font(.headline).foregroundStyle(Color.ground)
                    .padding(.horizontal, 28).padding(.vertical, 14)
                    .overlay(Capsule().stroke(Color.ground.opacity(0.25)))
            }.buttonStyle(.plain)
        }
        .onAppear { start() }
        .onDisappear {
            running = false
            runTask?.cancel()
            haptics.stop()
        }
    }

    private func start() {
        startedAt = Date()
        ended = false
        running = true
        haptics.prepare()
        runTask?.cancel()
        runTask = Task { await run() }
    }

    @MainActor
    private func run() async {
        let phases = practice.phases ?? []
        guard !phases.isEmpty else { end(); return }
        var i = 0
        while running && !Task.isCancelled {
            if Date().timeIntervalSince(startedAt) >= practice.durationSec { end(); return }
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

    private func end() {
        guard !ended else { return }
        ended = true
        running = false
        runTask?.cancel()
        haptics.stop()
        onDone(Int(Date().timeIntervalSince(startedAt)))
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

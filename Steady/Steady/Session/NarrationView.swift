import SwiftUI

/// Guided talk-through: reveals authored clinician-voice "beats" one at a time,
/// the way a calm guide would speak them. Deterministic copy — no model in the
/// session loop. Mirrors the web `NarrationView`.
struct NarrationView: View {
    let beats: [String]
    /// Speak a beat aloud as it appears (on-device). Default no-op keeps the
    /// view usable without voice; the session passes a Speaker-backed closure.
    var speak: (String) -> Void = { _ in }
    @State private var shown = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(beats.prefix(shown).enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(Color.ground.opacity(0.92))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            if shown < beats.count {
                Button {
                    withAnimation(.easeOut(duration: 0.4)) { shown += 1 }
                } label: {
                    Label("Continue reading", systemImage: "arrow.down")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.olive)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .animation(.easeOut(duration: 0.4), value: shown)
        .onAppear {
            // Speak the first beat, then gently auto-reveal so the member can just
            // listen/read, or tap to go faster.
            speak(beats.first ?? "")
            revealNext()
        }
        .onChange(of: shown) { _, newValue in
            // Each newly revealed beat is spoken in sequence (queued so it doesn't
            // cut off the previous one).
            if newValue >= 1, newValue <= beats.count { speak(beats[newValue - 1]) }
        }
    }

    private func revealNext() {
        guard shown < beats.count else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
            if shown < beats.count {
                withAnimation(.easeOut(duration: 0.4)) { shown += 1 }
                revealNext()
            }
        }
    }
}

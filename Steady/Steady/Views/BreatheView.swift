import SwiftUI

/// Breathwork library (roadmap F3). Backend-served, safety-ordered patterns; the
/// paced-breathing player is the shared BreathePacerView (also used by the
/// prepare-for-session on-ramp).
struct BreatheView: View {
    @Environment(Backend.self) private var backend

    @State private var practices: [PracticeDTO] = []
    @State private var selected: PracticeDTO?
    @State private var done = false
    @State private var loadError: String?

    var body: some View {
        ZStack {
            ScreenBackground()
            if let selected, !done {
                VStack {
                    BreathePacerView(practice: selected) { secs in
                        if secs >= 20 {
                            Task { try? await backend.completePractice(practiceId: selected.id, durationSec: secs) }
                        }
                        done = true
                    }
                }
                .padding(20)
            } else if selected != nil, done {
                doneScreen
            } else {
                library
            }
        }
        .task { await load() }
    }

    private func load() async {
        do { practices = try await backend.getPractices() }
        catch { loadError = "Couldn't load breathing patterns." }
    }

    private var library: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Breathe").serifTitle(34)
                Text("A few minutes of paced breathing to settle your system — before a session, or any time. Pick one that feels right; there's no wrong choice.")
                    .foregroundStyle(Color.olive)
                if let loadError { Text(loadError).font(.footnote).foregroundStyle(Color.support) }
                ForEach(practices) { p in
                    Button { done = false; selected = p } label: {
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

    private var doneScreen: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Nicely done").serifTitle(30)
            Text("That's a small, real act of care. Your breath is always here to come back to.")
                .foregroundStyle(Color.olive).multilineTextAlignment(.center).padding(.horizontal, 28)
            Spacer()
            PrimaryButton(title: "Another pattern") { selected = nil; done = false }
                .padding(.horizontal, 20).padding(.bottom, 24)
        }
    }
}

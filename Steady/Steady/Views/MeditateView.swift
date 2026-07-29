import SwiftUI

/// Copy + practice type that differ between the meditation (F2) and sleep (F5)
/// libraries. Same player and completion mechanics — only the framing changes.
struct LibraryCopy {
    let practiceType: String
    let heading: String
    let intro: String
    let loadError: String
    let footnote: String
    let doneTitle: String
    let doneBody: String
    let anotherLabel: String

    static let meditation = LibraryCopy(
        practiceType: "meditation",
        heading: "Meditate",
        intro: "Short, guided practices to steady and soothe — grounding, breath, calm-place, self-compassion. Read aloud, or follow along as text.",
        loadError: "Couldn't load meditations.",
        footnote: "Gentler, more grounding practices come first on days your check-in suggests taking it easy. Stop any time.",
        doneTitle: "Time well spent",
        doneBody: "You gave yourself a few quiet minutes. That's a real act of care — and it's always here when you need it.",
        anotherLabel: "Another practice"
    )

    static let sleep = LibraryCopy(
        practiceType: "sleep",
        heading: "Wind down for sleep",
        intro: "Guided wind-downs to do lying down, in the dark — slow breathing, melting into rest, putting the day down. Let them read aloud, dim your screen, and drift.",
        loadError: "Couldn't load wind-downs.",
        footnote: "Best done lying down with the lights low. Stop any time — and it's okay to fall asleep partway through.",
        doneTitle: "Rest well",
        doneBody: "However far you got, you gave your body a chance to let go. Sleep will come.",
        anotherLabel: "A different wind-down"
    )
}

/// Guided meditation / sleep library (roadmap F2 / F5). Backend-served,
/// safety-ordered scripts; the player reads each beat aloud on-device
/// (AVSpeechSynthesizer, the same Speaker the sessions use) and holds it for
/// its pace. Mirrors the web MeditationLibrary. Reached from the Dashboard.
struct MeditateView: View {
    var copy: LibraryCopy = .meditation
    @Environment(Backend.self) private var backend

    @State private var practices: [PracticeDTO] = []
    @State private var selected: PracticeDTO?
    @State private var done = false
    @State private var loadError: String?

    var body: some View {
        ZStack {
            ScreenBackground()
            if let selected, !done {
                MeditationPlayerView(practice: selected) { secs in
                    let threshold = max(30, Int((selected.durationSec / 3).rounded()))
                    if secs >= threshold {
                        Task { try? await backend.completePractice(practiceId: selected.id, durationSec: secs) }
                    }
                    done = true
                }
            } else if selected != nil, done {
                doneScreen
            } else {
                library
            }
        }
        .navigationTitle(copy.heading)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        do { practices = try await backend.getPractices(type: copy.practiceType) }
        catch { loadError = copy.loadError }
    }

    private var library: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(copy.heading).serifTitle(34)
                Text(copy.intro)
                    .foregroundStyle(Color.olive)
                if let loadError { Text(loadError).font(.footnote).foregroundStyle(Color.support) }
                ForEach(practices) { p in
                    Button { done = false; selected = p } label: {
                        SoftCard {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(p.title).font(.serifDisplay(22)).foregroundStyle(Color.ground)
                                    Spacer()
                                    Text("\(Int((p.durationSec / 60).rounded())) min")
                                        .font(.caption).foregroundStyle(Color.olive)
                                }
                                Text(p.intro).font(.subheadline).foregroundStyle(Color.olive)
                            }
                        }
                    }.buttonStyle(.plain)
                }
                Text(copy.footnote)
                    .font(.caption).foregroundStyle(Color.olive).padding(.top, 4)
            }
            .padding(20)
        }
    }

    private var doneScreen: some View {
        VStack(spacing: 20) {
            Spacer()
            Text(copy.doneTitle).serifTitle(30)
            Text(copy.doneBody)
                .foregroundStyle(Color.olive).multilineTextAlignment(.center).padding(.horizontal, 28)
            Spacer()
            PrimaryButton(title: copy.anotherLabel) { selected = nil; done = false }
                .padding(.horizontal, 20).padding(.bottom, 24)
        }
    }
}

/// Steps through a meditation's segments, reading each aloud on-device and
/// holding it for its pace. Pause stops speech and the timer; resume restarts
/// the current beat. Calls onDone(elapsedSec) at the end or when ended early.
struct MeditationPlayerView: View {
    let practice: PracticeDTO
    let onDone: (Int) -> Void

    @State private var idx = 0
    @State private var playing = true
    @State private var voiceOn = true
    @State private var startedAt = Date()
    @State private var speaker = Speaker()

    private var segments: [MeditationSegmentDTO] { practice.segments ?? [] }

    var body: some View {
        VStack(spacing: 28) {
            if segments.isEmpty {
                Text("This practice isn't available right now.").foregroundStyle(Color.olive)
            } else {
                progress
                Spacer()
                Text(segments[idx].text)
                    .font(.serifDisplay(24)).foregroundStyle(Color.ground)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                Spacer()
                controls
                if let note = practice.note {
                    Text(note).font(.caption).foregroundStyle(Color.olive)
                        .multilineTextAlignment(.center).padding(.horizontal, 24)
                }
            }
        }
        .padding(20)
        .task(id: "\(idx)|\(playing)") { await runBeat() }
        .onDisappear { speaker.stop() }
    }

    private var progress: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.moss).frame(height: 6)
                    Capsule().fill(Color.sageDeep)
                        .frame(width: geo.size.width * CGFloat(idx + 1) / CGFloat(max(1, segments.count)), height: 6)
                }
            }
            .frame(height: 6)
            Text(practice.title).font(.caption).foregroundStyle(Color.olive)
        }
    }

    private var controls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Button {
                    if playing { speaker.stop() }
                    playing.toggle()
                } label: {
                    Text(playing ? "Pause" : "Resume")
                        .font(.system(size: 16, weight: .medium)).foregroundStyle(Color.ground)
                        .padding(.horizontal, 28).padding(.vertical, 12)
                        .background(Color.sage, in: Capsule())
                }.buttonStyle(.plain)
                Button {
                    voiceOn.toggle()
                    if !voiceOn { speaker.stop() }
                } label: {
                    Text(voiceOn ? "Voice on" : "Voice off")
                        .font(.footnote).foregroundStyle(Color.ground.opacity(0.8))
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .overlay(Capsule().stroke(Color.ground.opacity(0.2)))
                }.buttonStyle(.plain)
            }
            Button("I'm done") { finish() }
                .font(.footnote).foregroundStyle(Color.olive)
        }
    }

    private func runBeat() async {
        guard playing, idx < segments.count else { return }
        let seg = segments[idx]
        if voiceOn { speaker.speak(seg.text) }
        try? await Task.sleep(nanoseconds: UInt64(seg.seconds * 1_000_000_000))
        if Task.isCancelled { return }
        if idx + 1 < segments.count { idx += 1 } else { finish() }
    }

    private func finish() {
        speaker.stop()
        onDone(Int(Date().timeIntervalSince(startedAt)))
    }
}

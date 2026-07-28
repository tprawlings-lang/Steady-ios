import SwiftUI

/// Baseline measures — the five validated instruments (PC-PTSD-5, PCL-5, ITQ,
/// PHQ-9, GAD-7). Item banks are served by the backend and scored server-side,
/// so the clinical scoring stays authoritative and never drifts.
struct MeasuresView: View {
    @Environment(Backend.self) private var backend
    @State private var info: MeasuresInfo?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Baseline check").serifTitle(30)
                        Text("A few short, standard questionnaires establish your starting point. These are screens, not diagnoses — your specialist interprets them.")
                            .font(.subheadline).foregroundStyle(Color.olive)
                        if let info {
                            ForEach(info.instruments) { inst in
                                let done = info.completed.contains(inst.id)
                                NavigationLink {
                                    InstrumentView(instrument: inst, onDone: { await reload() })
                                } label: { row(inst, done: done) }
                                .disabled(done)
                                .buttonStyle(.plain)
                            }
                            let remaining = info.instruments.filter { !info.completed.contains($0.id) }.count
                            if remaining == 0 {
                                Text("All done — continuing…").font(.subheadline).foregroundStyle(Color.safeDeep)
                            } else {
                                Text("\(remaining) of \(info.instruments.count) left").font(.caption).foregroundStyle(Color.olive)
                            }
                        } else if let error {
                            Text(error).foregroundStyle(Color.support)
                        } else {
                            ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Baseline").navigationBarTitleDisplayMode(.inline)
        }
        .task { await reload() }
    }

    private func row(_ inst: InstrumentDTO, done: Bool) -> some View {
        HStack {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? Color.safe : Color.olive)
            VStack(alignment: .leading, spacing: 2) {
                Text(inst.title).font(.system(size: 15, weight: .medium)).foregroundStyle(Color.ground).lineLimit(2)
                Text("\(inst.items.count) items").font(.caption).foregroundStyle(Color.olive)
            }
            Spacer()
            if !done { Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.olive) }
        }
        .padding(14)
        .background(Color.linen, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.ground.opacity(0.08)))
    }

    private func reload() async {
        do { info = try await backend.getMeasures() } catch { self.error = "Could not load the questionnaires." }
    }
}

/// Generic questionnaire renderer for any served instrument.
struct InstrumentView: View {
    let instrument: InstrumentDTO
    let onDone: () async -> Void

    @Environment(Backend.self) private var backend
    @Environment(\.dismiss) private var dismiss
    @State private var answers: [Int]
    @State private var busy = false
    @State private var error: String?
    @State private var showCrisis = false

    init(instrument: InstrumentDTO, onDone: @escaping () async -> Void) {
        self.instrument = instrument
        self.onDone = onDone
        _answers = State(initialValue: Array(repeating: -1, count: instrument.items.count))
    }

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(instrument.title).serifTitle(24)
                    Text(instrument.intro).font(.subheadline).foregroundStyle(Color.olive)
                    ForEach(Array(instrument.items.enumerated()), id: \.offset) { i, item in
                        if let heading = sectionHeading(before: i) {
                            Text(heading).font(.subheadline.weight(.semibold)).foregroundStyle(Color.ground)
                                .padding(.top, 6)
                        }
                        itemCard(index: i, text: item)
                    }
                    if let error { Text(error).foregroundStyle(Color.support) }
                    PrimaryButton(title: busy ? "Submitting…" : "Submit") { Task { await submit() } }
                        .disabled(busy || answers.contains(-1))
                }
                .padding(24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCrisis) { NavigationStack { CrisisView() } }
    }

    private func sectionHeading(before index: Int) -> String? {
        instrument.sections?.first { $0.startIndex == index }?.heading
    }

    private func itemCard(index i: Int, text: String) -> some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(i + 1). \(text)").font(.system(size: 15)).foregroundStyle(Color.ground)
                VStack(spacing: 6) {
                    ForEach(instrument.options, id: \.value) { opt in
                        Button { answers[i] = opt.value } label: {
                            HStack {
                                Image(systemName: answers[i] == opt.value ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(answers[i] == opt.value ? Color.sageDeep : Color.olive)
                                Text(opt.label).font(.subheadline).foregroundStyle(Color.ground)
                                Spacer()
                            }
                            .padding(.vertical, 8).padding(.horizontal, 12)
                            .background(answers[i] == opt.value ? Color.moss : Color.clear, in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func submit() async {
        error = nil; busy = true; defer { busy = false }
        do {
            let result = try await backend.submitMeasure(instrument: instrument.id, answers: answers)
            await onDone()
            if result.crisis { showCrisis = true } else { dismiss() }
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Could not submit."
        }
    }
}

import SwiftUI

/// The profile onboarding flow — support, background, triggers, warning signs,
/// readiness, safety plan, and companion preferences — written to the shared
/// account. Option sets are served by the backend (`profileCatalog`). Each step
/// saves server-side; the last marks the profile complete and the pipeline
/// router advances to the dashboard.
struct ProfileFlowView: View {
    @Environment(Backend.self) private var backend
    @State private var catalog: ProfileCatalog?
    @State private var step = 0
    @State private var busy = false
    @State private var error: String?
    @State private var showCrisis = false

    // step data
    @State private var therapistStatus = ""
    @State private var emdrExperience = ""
    @State private var goals: Set<String> = []
    @State private var traumaAreas: Set<String> = []
    @State private var restricted: Set<String> = []
    @State private var triggers: [TriggerInput] = []
    @State private var newTriggerName = ""
    @State private var newTriggerCat = "relational"
    @State private var newTriggerIntensity = 5.0
    @State private var warningSigns: Set<String> = []
    @State private var stability = 5.0
    @State private var bodySafety = 5.0
    @State private var presentConnection = 5.0
    @State private var symptomIntensity = 5.0
    @State private var sleep = "okay"
    @State private var support = "sometimes"
    @State private var processing = "unsure"
    @State private var pause = "not_sure"
    @State private var pace = "steady"
    @State private var risk = "none"
    @State private var safetyTools: Set<String> = []
    @State private var reminder = ""
    @State private var contactName = ""
    @State private var prefName = ""
    @State private var tone = "Gentle"
    @State private var modes: Set<String> = []
    @State private var avoidances: Set<String> = []
    @State private var memory = "yes"

    private let titles = ["About you", "Background", "Triggers", "Warning signs", "Readiness", "Safety plan", "Your companion"]

    var body: some View {
        ZStack {
            ScreenBackground()
            if let catalog {
                VStack(spacing: 0) {
                    ProgressView(value: Double(step + 1), total: Double(titles.count))
                        .tint(Color.sageDeep).padding()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(titles[min(step, titles.count - 1)]).serifTitle(28)
                            stepBody(catalog)
                            if let error { Text(error).foregroundStyle(Color.support) }
                        }
                        .padding(24)
                    }
                    PrimaryButton(title: busy ? "Saving…" : (step == titles.count - 1 ? "Finish" : "Continue")) {
                        Task { await saveAndAdvance(catalog) }
                    }
                    .disabled(busy).padding(.horizontal, 24).padding(.bottom, 12)
                }
            } else {
                ProgressView().task { await load() }
            }
        }
        .sheet(isPresented: $showCrisis) { NavigationStack { CrisisView() } }
    }

    // MARK: step bodies

    @ViewBuilder private func stepBody(_ cat: ProfileCatalog) -> some View {
        switch step {
        case 0:
            single("Are you working with a therapist?", cat.therapistStatus, $therapistStatus)
            single("Have you tried EMDR before?", cat.emdrExperience, $emdrExperience)
            multiStrings("What are you hoping for? (choose any)", cat.goals, $goals)
        case 1:
            multiStrings("Broad areas you'd like help with — headline level only, no detail.", cat.traumaAreas, $traumaAreas)
            multiStrings("Anything the companion should NOT bring up unless you do?", cat.traumaAreas, $restricted)
        case 2:
            triggerStep(cat)
        case 3:
            multiStrings("Which show up when you're getting activated? (choose any)", cat.warningSigns, $warningSigns)
        case 4:
            readinessStep(cat)
        case 5:
            multiStrings("Which grounding tools help you? (choose any)", cat.safetyTools, $safetyTools)
            labeledField("A reminder phrase for hard moments (optional)", $reminder)
            labeledField("A support person's name (optional)", $contactName)
        case 6:
            labeledField("What should the companion call you? (optional)", $prefName)
            single("Preferred tone", cat.tones.map { Labeled(value: $0, label: $0) }, $tone)
            multiStrings("How should it support you? (choose any)", cat.companionModes, $modes)
            multiStrings("Anything to avoid?", cat.companionAvoidances, $avoidances)
            single("Let the companion remember what helps you?",
                   [Labeled(value: "yes", label: "Yes"), Labeled(value: "ask", label: "Ask me"), Labeled(value: "no", label: "No")],
                   $memory)
        default: EmptyView()
        }
    }

    private func triggerStep(_ cat: ProfileCatalog) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add present-day triggers — a few words each. Optional.")
                .font(.subheadline).foregroundStyle(Color.olive)
            if !triggers.isEmpty {
                ForEach(triggers.indices, id: \.self) { i in
                    HStack {
                        Text("• \(triggers[i].name)").font(.subheadline)
                        Spacer()
                        Text("\(triggers[i].intensity ?? 5)/10").font(.caption).foregroundStyle(Color.olive)
                    }
                }
            }
            SoftCard {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("What sets it off?", text: $newTriggerName).textFieldStyle(.roundedBorder)
                    Picker("Category", selection: $newTriggerCat) {
                        ForEach(cat.triggerCategories) { Text($0.label).tag($0.value) }
                    }.pickerStyle(.menu)
                    VStack(alignment: .leading) {
                        Text("Intensity \(Int(newTriggerIntensity))/10").font(.caption)
                        Slider(value: $newTriggerIntensity, in: 1...10, step: 1).tint(Color.sage)
                    }
                    OutlineButton(title: "Add trigger") {
                        let n = newTriggerName.trimmingCharacters(in: .whitespaces)
                        guard !n.isEmpty else { return }
                        triggers.append(TriggerInput(category: newTriggerCat, name: n, intensity: Int(newTriggerIntensity), responses: []))
                        newTriggerName = ""; newTriggerIntensity = 5
                    }
                }
            }
        }
    }

    private func readinessStep(_ cat: ProfileCatalog) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            slider("How steady do you feel day to day?", $stability)
            slider("How safe does your body feel?", $bodySafety)
            slider("How present/connected do you feel?", $presentConnection)
            slider("How intense are your symptoms right now?", $symptomIntensity)
            single("How have you been sleeping?", cat.sleep, $sleep)
            single("Do you have support around you?", cat.support, $support)
            single("Do you feel ready to process difficult material?", cat.processing, $processing)
            single("Can you usually pause and settle when overwhelmed?", cat.pause, $pause)
            single("What pace feels right?", cat.pace, $pace)
            single("Any recent thoughts of harming yourself?", cat.risk, $risk)
        }
    }

    // MARK: components

    private func slider(_ label: String, _ b: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(label)  \(Int(b.wrappedValue))/10").font(.subheadline.weight(.medium))
            Slider(value: b, in: 0...10, step: 1).tint(Color.sage)
        }
    }
    private func labeledField(_ label: String, _ b: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.subheadline.weight(.medium))
            TextField("", text: b).textFieldStyle(.roundedBorder)
        }
    }
    private func single(_ label: String, _ options: [Labeled], _ sel: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.subheadline.weight(.medium))
            Chips(options.map { ($0.value, $0.label) }, isOn: { sel.wrappedValue == $0 }, tap: { sel.wrappedValue = $0 })
        }
    }
    private func multiStrings(_ label: String, _ options: [String], _ set: Binding<Set<String>>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.subheadline.weight(.medium))
            Chips(options.map { ($0, $0) }, isOn: { set.wrappedValue.contains($0) },
                  tap: { v in if set.wrappedValue.contains(v) { set.wrappedValue.remove(v) } else { set.wrappedValue.insert(v) } })
        }
    }

    // MARK: actions

    private func load() async {
        do { catalog = try await backend.getProfileCatalog() } catch { self.error = "Could not load onboarding." }
    }

    private func saveAndAdvance(_ cat: ProfileCatalog) async {
        error = nil; busy = true; defer { busy = false }
        do {
            switch step {
            case 0: try await backend.profileStep(SupportBody(therapistStatus: therapistStatus.isEmpty ? "prefer_not_to_say" : therapistStatus, emdrExperience: emdrExperience.isEmpty ? "not_sure" : emdrExperience, goals: Array(goals)))
            case 1: try await backend.profileStep(TraumaBody(areas: Array(traumaAreas), restrictedTopics: Array(restricted)))
            case 2: try await backend.profileStep(TriggersBody(triggers: triggers))
            case 3: try await backend.profileStep(WarningBody(signs: Array(warningSigns)))
            case 4:
                let r = try await backend.profileReadiness(ReadinessBody(
                    stability: Int(stability), bodySafety: Int(bodySafety), presentConnection: Int(presentConnection),
                    symptomIntensity: Int(symptomIntensity), sleep: sleep, support: support, processing: processing,
                    pause: pause, pace: pace, risk: risk))
                if r.crisis { showCrisis = true; return }   // stay; onboarding incomplete until safe
            case 5:
                try await backend.profileStep(SafetyBody(tools: Array(safetyTools), contactName: contactName, reminder: reminder))
            case 6:
                try await backend.profileStep(CompanionBody(preferredName: prefName, tone: tone, modes: Array(modes), avoidances: Array(avoidances), memory: memory))
                try await backend.profileStep(CompleteBody())
                return   // loadMe (inside profileStep) refreshes gating → router advances
            default: break
            }
            if step < titles.count - 1 { step += 1 }
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Could not save this step."
        }
    }
}

// MARK: - Encodable step bodies

struct TriggerInput: Codable, Equatable {
    let category: String
    let name: String
    let intensity: Int?
    let responses: [String]?
}
private struct SupportBody: Encodable { let step = "support"; let therapistStatus: String; let emdrExperience: String; let goals: [String] }
private struct TraumaBody: Encodable { let step = "trauma"; let areas: [String]; let restrictedTopics: [String] }
private struct TriggersBody: Encodable { let step = "triggers"; let triggers: [TriggerInput] }
private struct WarningBody: Encodable { let step = "warning-signs"; let signs: [String] }
private struct ReadinessBody: Encodable {
    let step = "readiness"
    let stability: Int; let bodySafety: Int; let presentConnection: Int; let symptomIntensity: Int
    let sleep: String; let support: String; let processing: String; let pause: String; let pace: String; let risk: String
}
private struct SafetyBody: Encodable { let step = "safety-plan"; let tools: [String]; let contactName: String; let reminder: String }
private struct CompanionBody: Encodable { let step = "companion"; let preferredName: String; let tone: String; let modes: [String]; let avoidances: [String]; let memory: String }
private struct CompleteBody: Encodable { let step = "complete" }

// MARK: - Chips

/// Simple wrapping chip selector.
struct Chips: View {
    let options: [(String, String)]     // (value, label)
    let isOn: (String) -> Bool
    let tap: (String) -> Void
    init(_ options: [(String, String)], isOn: @escaping (String) -> Bool, tap: @escaping (String) -> Void) {
        self.options = options; self.isOn = isOn; self.tap = tap
    }
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.0) { opt in
                Button { tap(opt.0) } label: {
                    Text(opt.1)
                        .font(.subheadline)
                        .foregroundStyle(isOn(opt.0) ? Color.ground : Color.ground.opacity(0.8))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(isOn(opt.0) ? Color.clay : Color.linen, in: Capsule())
                        .overlay(Capsule().stroke(Color.ground.opacity(0.15)))
                }.buttonStyle(.plain)
            }
        }
    }
}

/// Minimal flow layout for wrapping chips (iOS 16+).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > maxWidth { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += s.width + spacing; rowHeight = max(rowHeight, s.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, rowHeight: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x - bounds.minX + s.width > maxWidth { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing; rowHeight = max(rowHeight, s.height)
        }
    }
}

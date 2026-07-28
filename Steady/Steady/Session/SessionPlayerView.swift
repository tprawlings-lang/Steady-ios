import SwiftUI
import SwiftData
import Combine

/// The guided session — a faithful native port of the web `SessionPlayer`.
/// Deterministic safety rules (SUDS pause/hard-stop, mid-session rise, time
/// caps) come straight from `SessionSafety`. Bilateral stimulation is native
/// (dot + stereo tones + haptics).
struct SessionPlayerView: View {
    let module: TherapyModule

    @Environment(AppState.self) private var app
    @Environment(Backend.self) private var backend
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    enum Phase { case intro, running, ground, sudpause, hardstop, complete }
    enum BLSMode { case visual, audio }

    @State private var phase: Phase = .intro
    @State private var stepIndex = 0
    @State private var sudsTrail: [Int] = []
    @State private var currentSuds = 5
    @State private var blsMode: BLSMode = .visual
    @State private var speedMs: Double = 2400
    // Tones on by default — the narration promises "a slow, steady rhythm plays
    // underneath"; a silent session is the common "I can't hear anything".
    @State private var soundOn = true
    @State private var blsStarted = false
    @State private var blsSet = 1
    @State private var blsSecondsLeft = 0
    @State private var blsResting = false
    @State private var windDown = false
    @State private var capped = false
    @State private var startedAt: Date?
    @State private var hardStopReason = ""
    @State private var customFocus = ""
    @State private var engine: BilateralEngine?
    @State private var pulser = AudioPulser()
    @State private var showCrisis = false
    @State private var didSave = false
    /// Server-side session id when signed in and online; nil = local-only.
    @State private var serverSessionId: String?

    // Hands-free live voice (opt-in; only when the account has it enabled).
    @State private var liveEnabled = false
    @State private var liveTurns: [LiveTurn] = []
    @State private var liveBusy = false
    @State private var speech = SpeechRecognizer()
    @State private var speaker = Speaker()
    /// Spoken guidance (narration + directive cues) on by default; members can mute.
    @State private var voiceOn = true
    // Prepare-for-session on-ramp (F4).
    @State private var preparePractice: PracticeDTO?
    @State private var preparing = false
    @State private var prepared = false
    private var liveVoiceAvailable: Bool { backend.gating?.liveVoiceAvailable == true }
    private var liveVoiceOn: Bool { liveEnabled && liveVoiceAvailable }

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var step: SessionStep? {
        guard stepIndex < module.steps.count else { return nil }
        return module.steps[stepIndex]
    }
    private var preSuds: Int? { sudsTrail.first }
    private var peakSuds: Int? { sudsTrail.max() }
    private var chosenFocus: String { customFocus.trimmingCharacters(in: .whitespaces) }

    // Directive cues spoken/shown DURING a set — only for positive-resource
    // (autonomous-tier) modules like the calm place, personalized to the member's
    // place. NOT for gated trauma-processing sets, where they'd be clinically wrong.
    private var isResourcing: Bool { module.tier == .autonomous }
    private var blsCues: [String] { ResourcingCues.cues(place: app.calmPlace.isEmpty ? nil : app.calmPlace) }
    private var currentCue: String { blsCues[max(0, blsSet - 1) % blsCues.count] }
    private func speakSetCue() {
        guard isResourcing, voiceOn else { return }
        speaker.speak(currentCue)   // one light cue at each set start (replaces prior)
    }

    var body: some View {
        ZStack {
            ScreenBackground()
            content
        }
        .navigationBarBackButtonHidden(phase == .running)
        .sheet(isPresented: $showCrisis) { NavigationStack { CrisisView() } }
        .onReceive(tick) { _ in onTick() }
        .onDisappear { teardown() }
        .onAppear { blsMode = app.audioOnlyDefault ? .audio : .visual }
        .task { if preparePractice == nil { preparePractice = try? await backend.getPractices().first } }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .intro:
            if preparing, let p = preparePractice {
                VStack(spacing: 16) {
                    Text("Taking a moment to settle before we begin.").foregroundStyle(Color.olive)
                    BreathePacerView(practice: p) { secs in
                        preparing = false
                        prepared = true
                        if secs >= 20 { Task { try? await backend.completePractice(practiceId: p.id, durationSec: secs) } }
                        Task { await backend.recordSessionPrepare(moduleId: module.id) }
                    }
                }
                .padding(20)
            } else {
                introView
            }
        case .running:  runningView
        case .ground, .sudpause: groundView
        case .hardstop: hardStopView
        case .complete: completeView
        }
    }

    // MARK: - Intro

    private var introView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                NotForEmergenciesBanner()
                Text(module.name).serifTitle(34)
                Text(module.objective).foregroundStyle(Color.olive)

                SoftCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Give today a focus (optional)").font(.headline)
                        Text("You can name what you'd like to work with, or just begin.")
                            .font(.subheadline).foregroundStyle(Color.olive)
                        TextField("Describe your own focus", text: $customFocus)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                SoftCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("About \(module.durationLabel). You can pause or stop at any time — stopping early is always allowed. If distress climbs too high, the session ends itself and offers grounding.")
                            .font(.subheadline).foregroundStyle(Color.ground.opacity(0.9))

                        Text("Bilateral stimulation").font(.subheadline.weight(.semibold))
                        Picker("Mode", selection: $blsMode) {
                            Text("Moving dot").tag(BLSMode.visual)
                            Text("Audio only").tag(BLSMode.audio)
                        }
                        .pickerStyle(.segmented)
                        if app.audioOnlyDefault {
                            Text("Audio-only is your default based on your fit answers — gentler for photosensitivity. You can change it.")
                                .font(.caption).foregroundStyle(Color.olive)
                        }
                        if blsMode == .visual {
                            Toggle("Add alternating audio tones (left/right)", isOn: $soundOn)
                                .font(.subheadline)
                        }
                        HStack {
                            Text("Pace").font(.subheadline)
                            Picker("Pace", selection: $speedMs) {
                                Text("Slow").tag(3200.0)
                                Text("Medium").tag(2400.0)
                                Text("Faster").tag(1700.0)
                            }.pickerStyle(.menu)
                        }
                        Toggle("Haptic taps (left/right)", isOn: Binding(
                            get: { app.hapticsEnabled },
                            set: { app.hapticsEnabled = $0 }))
                            .font(.subheadline)
                        Toggle("Spoken guidance (voice)", isOn: $voiceOn)
                            .font(.subheadline)
                        if voiceOn, !speaker.hasNaturalVoice {
                            Text("Tip: for a warmer, more natural narrator, download an enhanced voice once in Settings ▸ Accessibility ▸ Spoken Content ▸ Voices.")
                                .font(.caption).foregroundStyle(Color.olive)
                        }
                        if liveVoiceAvailable {
                            Toggle(isOn: $liveEnabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Talk with me (hands-free)").font(.subheadline)
                                    Text("Speak during the guided steps; I'll respond out loud. On-device transcription — only text is sent.")
                                        .font(.caption).foregroundStyle(Color.olive)
                                }
                            }.font(.subheadline)
                        }
                    }
                }

                if preparePractice != nil {
                    SoftCard {
                        if prepared {
                            Text("✓ You took a moment to settle. Begin whenever you're ready.")
                                .font(.subheadline).foregroundStyle(Color.sageDeep)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Prepare first (optional)").font(.subheadline.weight(.medium))
                                Text("A short paced breath to settle before you start — about a minute. Steadier going in tends to make the work gentler.")
                                    .font(.caption).foregroundStyle(Color.olive)
                                Button("Prepare with a breath") { preparing = true }
                                    .font(.subheadline.weight(.medium)).foregroundStyle(Color.sageDeep)
                            }
                        }
                    }
                }

                PrimaryButton(title: chosenFocus.isEmpty ? "Begin slowly" : "Begin slowly — focus: \(chosenFocus)") {
                    begin()
                }
            }
            .padding(20)
        }
    }

    // MARK: - Running

    private var runningView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if windDown {
                    Text("You've been at this a while. Sessions wind down around \(SessionSafety.sessionWinddownMin) minutes — start letting the work settle.")
                        .font(.footnote).foregroundStyle(Color.ground)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.pauseSoft, in: RoundedRectangle(cornerRadius: 18))
                }
                HStack {
                    Text("\(module.name) · step \(stepIndex + 1) of \(module.steps.count)")
                        .font(.caption).foregroundStyle(Color.olive)
                    Spacer()
                    Button {
                        voiceOn.toggle()
                        if !voiceOn { speaker.stop() }
                    } label: {
                        Image(systemName: voiceOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    }
                    .font(.caption).foregroundStyle(Color.olive)
                    .accessibilityLabel(voiceOn ? "Voice on" : "Voice off")
                    Button("Exit") { endSession(outcome: "abandoned") }
                        .font(.caption).foregroundStyle(Color.olive)
                }
                if !chosenFocus.isEmpty {
                    Text("Focus: \(chosenFocus)")
                        .font(.caption.weight(.medium)).foregroundStyle(Color.ground)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Color.clay.opacity(0.6), in: Capsule())
                }

                stepBody

                if let preSuds {
                    Text("Start distress \(preSuds) · peak \(peakSuds ?? preSuds)")
                        .font(.caption2).foregroundStyle(Color.olive)
                        .frame(maxWidth: .infinity, alignment: .center).padding(.top, 8)
                }
                Color.clear.frame(height: 80)
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button {
                    groundMe()
                } label: {
                    Text("Ground me")
                        .font(.headline).foregroundStyle(.white)
                        .padding(.horizontal, 28).padding(.vertical, 16)
                        .background(Color.support, in: Capsule())
                        .shadow(radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20).padding(.bottom, 8)
            }
        }
    }

    @ViewBuilder private var stepBody: some View {
        switch step?.kind {
        case .instruction?, .grounding?:
            VStack(alignment: .leading, spacing: 14) {
                Text(step?.title ?? "").serifTitle(24)
                if let beats = step?.beats, !beats.isEmpty {
                    NarrationView(
                        beats: beats.map { fillNarrationSlots($0, calmPlace: app.calmPlace, name: app.name) },
                        speak: { if voiceOn { speaker.speak($0, queue: true) } })
                        .id(stepIndex)
                } else if let t = step?.text {
                    Text(t).font(.system(size: 19)).foregroundStyle(Color.ground.opacity(0.9))
                }
                if liveVoiceOn { liveVoicePanel.padding(.top, 4) }
                PrimaryButton(title: "Continue") { advance() }
                    .padding(.top, 6)
            }
        case .suds?:
            VStack(alignment: .leading, spacing: 18) {
                Text(step?.title ?? "").serifTitle(24)
                VStack(spacing: 6) {
                    Slider(value: Binding(
                        get: { Double(currentSuds) },
                        set: { currentSuds = Int($0.rounded()) }), in: 0...10, step: 1)
                    .tint(Color.sage)
                    HStack {
                        Text("0 — no distress").font(.caption).foregroundStyle(Color.olive)
                        Spacer()
                        Text("\(currentSuds)").font(.title.bold()).foregroundStyle(Color.ground)
                        Spacer()
                        Text("10 — worst").font(.caption).foregroundStyle(Color.olive)
                    }
                }
                PrimaryButton(title: "Record \(currentSuds) and continue") { submitSuds() }
            }
        case .bls?:
            blsBody
        case .triggerEntry?:
            TriggerEntryStep(text: step?.text, sessionId: serverSessionId, onDone: { advance() })
        case .none:
            EmptyView()
        }
    }

    private var blsBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(step?.title ?? "").serifTitle(24)
            Group {
                if blsMode == .audio {
                    VStack(spacing: 8) {
                        Text(blsStarted && !blsResting ? "Follow the tones" : "Audio paused")
                            .font(.serifDisplay(24)).foregroundStyle(Color.ivory)
                        Text("Left… right… let your attention move with the sound. Headphones work best.")
                            .font(.footnote).foregroundStyle(Color.ivory.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).frame(height: 220)
                    .background(Color.ground, in: RoundedRectangle(cornerRadius: 24))
                } else {
                    BLSVisualView(
                        running: blsStarted && !blsResting && blsSecondsLeft > 0,
                        speedMs: speedMs,
                        onSide: { side in
                            engine?.pulse(side: side, sound: soundOn, haptic: app.hapticsEnabled)
                        })
                }
            }
            if isResourcing, blsStarted, !blsResting {
                Text(currentCue)
                    .font(.serifDisplay(22)).foregroundStyle(Color.ground)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            if !blsStarted {
                PrimaryButton(title: "Start set 1 of \(step?.sets ?? 1) (\(step?.durationSec ?? 30)s each)") {
                    startBls()
                }
            } else {
                Text(blsResting
                     ? "Rest. Breathe out slowly… next set in \(blsSecondsLeft)s"
                     : "Set \(blsSet) of \(step?.sets ?? 1) — \(blsMode == .audio ? "follow the tones left and right" : "follow the dot with your eyes") · \(blsSecondsLeft)s")
                    .font(.system(size: 18)).foregroundStyle(Color.ground)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            Text("Feeling too much? Use \u{201C}Exit\u{201D} above — stopping is always allowed.")
                .font(.caption).foregroundStyle(Color.olive)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: - Ground / SUDS-pause

    private var groundView: some View {
        ScrollView {
            SoftCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text(phase == .sudpause ? "Let's pause and settle first" : "Coming back to the room")
                        .serifTitle(26)
                    if phase == .sudpause {
                        Text("Your distress is high enough that pushing on isn't the right move. Ground first — then you choose.")
                            .foregroundStyle(Color.olive)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        groundingStep(1, "Feel your feet on the floor. Press them down gently.")
                        groundingStep(2, "Breathe out longer than you breathe in. Three slow breaths.")
                        groundingStep(3, "Name five things you can see, four you can hear, three you can touch, two you can smell, one you can taste.")
                        groundingStep(4, "Look around the room. Notice where you are, today's date, that you are here now.")
                        if !app.calmPlace.isEmpty {
                            groundingStep(5, "Say your calm-place word to yourself: \u{201C}\(app.calmPlace)\u{201D}.")
                        }
                    }
                    PrimaryButton(title: phase == .sudpause ? "I'm steadier — continue gently" : "I'm steadier — back to the session") {
                        let wasPause = phase == .sudpause
                        phase = .running
                        if wasPause { advance() }
                    }
                    OutlineButton(title: "End the session here — stopping is always allowed") {
                        endSession(outcome: "abandoned")
                    }
                    Button("I need more help than grounding") { showCrisis = true }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Color.support)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
        }
    }

    private func groundingStep(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n).").font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.sageDeep)
            Text(text).font(.system(size: 18)).foregroundStyle(Color.ground.opacity(0.9))
        }
    }

    // MARK: - Hard stop

    private var hardStopView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Session paused for your safety").serifTitle(26)
                Text("\(hardStopReason). That is the system working as designed — not a failure. Your care team has been notified and will review this session.")
                    .foregroundStyle(Color.ground.opacity(0.9))
                SoftCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ground yourself now").font(.headline)
                        groundingStep(1, "Feel your feet on the floor. Press them down.")
                        groundingStep(2, "Name five things you can see in the room.")
                        groundingStep(3, "Breathe out longer than you breathe in, five times.")
                        groundingStep(4, app.calmPlace.isEmpty
                            ? "If you saved a calm-place word, say it to yourself now."
                            : "Say your calm-place word to yourself now: \u{201C}\(app.calmPlace)\u{201D}.")
                    }
                }
                Button {
                    showCrisis = true
                } label: {
                    Text("I need help now").font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.support, in: Capsule())
                }.buttonStyle(.plain)
                OutlineButton(title: "I am settled — back to home") { dismiss() }
            }
            .padding(20)
            .background(Color.pauseSoft.opacity(0.4))
        }
    }

    // MARK: - Complete

    private var completeView: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 52)).foregroundStyle(Color.safe)
                Text("Session complete").serifTitle(28)
                if let pre = preSuds, let post = sudsTrail.last {
                    SoftCard {
                        VStack(spacing: 6) {
                            Text("Distress this session").font(.subheadline).foregroundStyle(Color.olive)
                            Text("\(pre) → \(post)").font(.system(size: 40, weight: .semibold, design: .serif))
                                .foregroundStyle(post <= pre ? Color.safeDeep : Color.ground)
                            Text("Peak \(peakSuds ?? pre)").font(.caption).foregroundStyle(Color.olive)
                        }.frame(maxWidth: .infinity)
                    }
                }
                Text("Nicely done for showing up for yourself today.")
                    .foregroundStyle(Color.olive).multilineTextAlignment(.center)
                PrimaryButton(title: "Back to home") { dismiss() }
            }
            .padding(24)
        }
    }

    // MARK: - Flow

    private func begin() {
        startedAt = Date()
        engine = BilateralEngine()
        phase = .running
        // Open a server session so the gate is enforced and the clinician's
        // view sees it. If offline or denied, the session still runs locally.
        if backend.isAuthenticated {
            // For the calm-place module, the member's calm place IS the focus —
            // sending it persists it to the server "calm place" memory slot
            // (parity with web), so it's durable and shows up on other devices.
            let focus: String? = chosenFocus.isEmpty
                ? (module.id == "calm-place" && !app.calmPlace.isEmpty ? app.calmPlace : nil)
                : chosenFocus
            Task { @MainActor in serverSessionId = try? await backend.startSession(moduleId: module.id, focus: focus) }
        }
    }

    private func emitSafety(_ type: String) {
        guard backend.isAuthenticated else { return }
        let sid = serverSessionId
        Task { await backend.postSafetyEvent(type: type, sessionId: sid) }
    }

    private func groundMe() {
        blsStarted = false
        pulser.stop()
        speech.stop()
        speaker.stop()
        phase = .ground
        emitSafety("ground_me_pressed")
    }

    // MARK: - Live voice

    private func toggleListening() {
        if speech.isListening { speech.finish(); return }
        if speech.authorized {
            speech.start(onUtterance: handleUtterance)
        } else {
            speech.requestAuthorization { ok in
                if ok { speech.start(onUtterance: handleUtterance) }
            }
        }
    }

    private func handleUtterance(_ text: String) {
        guard !liveBusy, let sid = serverSessionId else { return }
        liveTurns.append(LiveTurn(role: "you", text: text))
        liveBusy = true
        Task { @MainActor in
            defer { liveBusy = false }
            do {
                let res = try await backend.speakInSession(
                    sessionId: sid, moduleId: module.id, transcript: text,
                    currentSuds: sudsTrail.last,
                    calmPlace: app.calmPlace.isEmpty ? nil : app.calmPlace,
                    name: app.name.isEmpty ? nil : app.name)
                if res.ok, let r = res.response {
                    liveTurns.append(LiveTurn(role: "steady", text: r.text))
                    speaker.speak(r.text)
                    // suggestGroundMe is a UI hint only; the engine's stops are independent.
                    if r.suggestGroundMe { groundMe() }
                }
            } catch {
                // A failed turn is silent — the deterministic session is unaffected.
            }
        }
    }

    private var liveVoicePanel: some View {
        SoftCard(background: Color.moss) {
            VStack(alignment: .leading, spacing: 10) {
                if !liveTurns.isEmpty {
                    ForEach(liveTurns.suffix(4)) { t in
                        Text(t.role == "you" ? "You: \(t.text)" : t.text)
                            .font(.system(size: 15))
                            .foregroundStyle(t.role == "you" ? Color.olive : Color.ground.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: t.role == "you" ? .trailing : .leading)
                    }
                }
                if speech.isListening, !speech.transcript.isEmpty {
                    Text(speech.transcript).font(.caption).foregroundStyle(Color.olive)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                HStack {
                    Button { toggleListening() } label: {
                        Label(speech.isListening ? "Listening… tap when done" : "Tap to speak",
                              systemImage: speech.isListening ? "waveform.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(speech.isListening ? Color.support : Color.sageDeep)
                    }.buttonStyle(.plain)
                    Spacer()
                    if liveBusy { ProgressView() }
                }
                if let e = speech.errorText { Text(e).font(.caption).foregroundStyle(Color.support) }
                Text("Speech is transcribed on your device; only the text is sent. Grounding and stops always stay in your control.")
                    .font(.caption2).foregroundStyle(Color.olive)
            }
        }
    }

    private func startBls() {
        blsStarted = true
        blsSet = 1
        blsSecondsLeft = step?.durationSec ?? 30
        blsResting = false
        if blsMode == .audio { startPulser() }
        speakSetCue()
    }

    private func startPulser() {
        pulser.start(speedMs: speedMs, haptic: app.hapticsEnabled) { side, haptic in
            engine?.pulse(side: side, sound: true, haptic: haptic)
        }
    }

    private func submitSuds() {
        let trail = sudsTrail + [currentSuds]
        sudsTrail = trail
        switch SessionSafety.sudsDecision(trail) {
        case .hardStop:
            triggerHardStop(reason: "Distress rated \(currentSuds)/10", trail: trail)
        case .pause:
            blsStarted = false
            pulser.stop()
            phase = .sudpause
            emitSafety("suds_pause")
        case .cont:
            advance()
        }
    }

    private func advance() {
        blsStarted = false
        pulser.stop()
        speech.stop()
        speaker.stop()   // don't let one step's narration bleed into the next
        if stepIndex + 1 >= module.steps.count {
            endSession(outcome: "completed")
        } else {
            stepIndex += 1
        }
    }

    private func triggerHardStop(reason: String, trail: [Int]) {
        hardStopReason = reason
        blsStarted = false
        pulser.stop()
        engine?.stop()
        saveSession(outcome: "hard_stop", reason: reason, trail: trail)
        phase = .hardstop
    }

    private func endSession(outcome: String) {
        blsStarted = false
        pulser.stop()
        engine?.stop()
        saveSession(outcome: outcome, reason: nil, trail: sudsTrail)
        if outcome == "completed" {
            phase = .complete
        } else {
            dismiss()
        }
    }

    private func saveSession(outcome: String, reason: String?, trail: [Int]) {
        guard !didSave else { return }
        didSave = true
        let record = SessionRecord(
            moduleId: module.id, moduleName: module.name,
            startedAt: startedAt ?? Date(), outcome: outcome,
            preSuds: trail.first, postSuds: trail.last, peakSuds: trail.max(),
            sudsTrail: trail, focus: chosenFocus.isEmpty ? nil : chosenFocus,
            hardStopReason: reason, remoteId: serverSessionId)
        context.insert(record)
        try? context.save()

        // Record the outcome to the shared account so it syncs to the web + the
        // clinician's review. Best-effort; the local record is authoritative here.
        if backend.isAuthenticated, let sid = serverSessionId {
            Task {
                try? await backend.finishSession(
                    sessionId: sid, outcome: outcome,
                    preSuds: trail.first, postSuds: trail.last, peakSuds: trail.max(),
                    hardStopReason: reason, sudsTrail: trail)
            }
        }
    }

    // MARK: - Timers

    private func onTick() {
        guard phase == .running else { return }
        // Session time caps (compliance 4B.3).
        if let startedAt, !capped {
            let mins = Date().timeIntervalSince(startedAt) / 60
            if mins >= Double(SessionSafety.sessionCapMin) {
                capped = true
                blsStarted = false
                pulser.stop()
                stepIndex = module.steps.count - 1   // jump to closing grounding step
                emitSafety("session_time_cap")
            } else if mins >= Double(SessionSafety.sessionWinddownMin) {
                if !windDown { emitSafety("session_winddown_shown") }
                windDown = true
            }
        }
        // BLS set/rest engine.
        guard step?.kind == .bls, blsStarted else { return }
        if blsSecondsLeft > 1 {
            blsSecondsLeft -= 1
            return
        }
        if blsResting {
            // Rest finished → next set or step done.
            if blsSet >= (step?.sets ?? 1) {
                blsStarted = false
                pulser.stop()
                advance()
            } else {
                blsSet += 1
                blsSecondsLeft = step?.durationSec ?? 30
                blsResting = false
                if blsMode == .audio { startPulser() }
                speakSetCue()
            }
        } else {
            // Set finished → micro-pause.
            blsResting = true
            blsSecondsLeft = SessionSafety.restSeconds
            pulser.stop()
        }
    }

    private func teardown() {
        pulser.stop()
        engine?.stop()
        speech.stop()
        speaker.stop()
    }
}

/// Structured trigger capture (Module 5) — headline-level entries kept on-device.
private struct TriggerEntryStep: View {
    let text: String?
    /// The open server session; trigger entries persist to the account when set.
    let sessionId: String?
    let onDone: () -> Void

    @Environment(Backend.self) private var backend
    @State private var saved: [String] = []
    @State private var name = ""
    @State private var bodyFelt = ""
    @State private var belief = ""
    @State private var disruption = 5.0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Map your triggers (headline level)").serifTitle(24)
            if let text { Text(text).font(.subheadline).foregroundStyle(Color.olive) }
            if !saved.isEmpty {
                FlexWrap(saved) { s in
                    Text("✓ \(s)").font(.caption).padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.safe.opacity(0.2), in: Capsule())
                }
            }
            SoftCard {
                VStack(alignment: .leading, spacing: 12) {
                    field("What sets it off? (a few words)", "e.g. Raised voices, hospital smells", $name)
                    field("Where do you feel it in your body?", "e.g. Tight chest, clenched jaw", $bodyFelt)
                    field("The belief that comes with it", "e.g. I am not safe · It was my fault", $belief)
                    VStack(alignment: .leading) {
                        Text("How disruptive is it day to day? \(Int(disruption))/10").font(.subheadline.weight(.medium))
                        Slider(value: $disruption, in: 1...10, step: 1).tint(Color.sage)
                    }
                    Button {
                        let n = name.trimmingCharacters(in: .whitespaces)
                        guard !n.isEmpty else { return }
                        // Persist to the account (encrypted user_triggers) so it
                        // reaches the program plan + specialist, exactly like web.
                        if let sid = sessionId {
                            let b = bodyFelt, bel = belief, d = Int(disruption)
                            Task { try? await backend.postSessionTrigger(
                                sessionId: sid, name: n, bodyFelt: b, belief: bel, disruption: d) }
                        }
                        saved.append(n); name = ""; bodyFelt = ""; belief = ""; disruption = 5
                    } label: {
                        Text("Save this trigger to my map").frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .overlay(Capsule().stroke(Color.ground, lineWidth: 1))
                    }.buttonStyle(.plain).foregroundStyle(Color.ground)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            PrimaryButton(title: saved.isEmpty ? "Continue without adding" : "Done for today — \(saved.count) saved, continue") { onDone() }
            Text("Headlines only — a few words is enough. If distress climbs above 6, stop here and use \u{201C}Ground me.\u{201D}")
                .font(.caption).foregroundStyle(Color.olive).frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func field(_ label: String, _ placeholder: String, _ binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.subheadline.weight(.medium))
            TextField(placeholder, text: binding).textFieldStyle(.roundedBorder)
        }
    }
}

/// Very small wrapping layout for chips.
private struct FlexWrap<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let content: (Data.Element) -> Content
    init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data; self.content = content
    }
    var body: some View {
        HStack { ForEach(Array(data), id: \.self) { content($0) }; Spacer() }
    }
}

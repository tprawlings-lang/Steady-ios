import Foundation
import Speech
import AVFoundation
import Observation

/// One turn in the spoken exchange overlaid on a session.
struct LiveTurn: Identifiable, Equatable {
    let id = UUID()
    let role: String   // "you" | "steady"
    let text: String
}

/// On-device speech-to-text for hands-free sessions. Transcription runs on the
/// device (Apple Speech framework) — only the resulting text is sent to the
/// server, matching the voice-consent copy. Requires the voice/biometric
/// consent (granted server-side) plus the OS mic + speech permissions.
@Observable
final class SpeechRecognizer {
    var transcript: String = ""
    var isListening: Bool = false
    var authorized: Bool = false
    var errorText: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?
    private var onUtterance: ((String) -> Void)?

    var isAvailable: Bool { recognizer?.isAvailable ?? false }

    /// Ask for speech + microphone permission. Completion on the main thread.
    func requestAuthorization(_ done: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            let speechOK = status == .authorized
            AVAudioApplication.requestRecordPermission { micOK in
                DispatchQueue.main.async {
                    self.authorized = speechOK && micOK
                    done(self.authorized)
                }
            }
        }
    }

    /// Start listening. `onUtterance` fires (on main) after a short silence with
    /// the finalized text, and listening stops so the caller can respond.
    func start(onUtterance: @escaping (String) -> Void) {
        guard !isListening else { return }
        self.onUtterance = onUtterance
        transcript = ""
        errorText = nil

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorText = "Couldn't start the microphone."
            return
        }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer?.supportsOnDeviceRecognition == true {
            req.requiresOnDeviceRecognition = true   // keep audio on device
        }
        request = req

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        audioEngine.prepare()
        do { try audioEngine.start() } catch { errorText = "Couldn't start audio."; return }

        isListening = true
        task = recognizer?.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.transcript = text
                    self.resetSilenceTimer()
                }
            }
            if error != nil || (result?.isFinal ?? false) {
                DispatchQueue.main.async { self.finish() }
            }
        }
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        // Auto-finalize ~1.6s after the member stops speaking.
        let t = Timer(timeInterval: 1.6, repeats: false) { [weak self] _ in
            DispatchQueue.main.async { self?.finish() }
        }
        RunLoop.main.add(t, forMode: .common)
        silenceTimer = t
    }

    /// Finalize the current utterance and hand it back.
    func finish() {
        guard isListening else { return }
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        stop()
        if !text.isEmpty { onUtterance?(text) }
    }

    func stop() {
        silenceTimer?.invalidate(); silenceTimer = nil
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        request = nil; task = nil
        isListening = false
    }

    deinit { stop() }
}

/// Speaks deterministic guidance aloud — narration beats and the short directive
/// cues during a calm-place set, plus the companion's reply. Picks the most
/// natural installed voice instead of the robotic default. On-device
/// (AVSpeechSynthesizer); nothing is uploaded. Text is always shown too.
final class Speaker {
    private let synth = AVSpeechSynthesizer()
    private lazy var preferredVoice: AVSpeechSynthesisVoice? = Self.bestVoice()

    /// Speak `text`. `queue: true` appends after whatever is already speaking
    /// (for sequential narration beats); otherwise it replaces the current
    /// utterance (for a fresh set cue).
    func speak(_ text: String, queue: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !queue { synth.stopSpeaking(at: .immediate) }
        let u = AVSpeechUtterance(string: trimmed)
        u.rate = 0.46            // calm, unhurried
        u.pitchMultiplier = 0.98
        u.voice = preferredVoice ?? AVSpeechSynthesisVoice(language: "en-US")
        synth.speak(u)
    }

    func stop() { synth.stopSpeaking(at: .immediate) }

    /// The most natural English voice the device offers: prefer premium/enhanced
    /// quality and a pleasant modern named voice over the compact default; avoid
    /// the legacy novelty voices.
    private static func bestVoice() -> AVSpeechSynthesisVoice? {
        let english = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
        guard !english.isEmpty else { return nil }
        let nice = ["samantha", "ava", "allison", "evan", "zoe", "nathan", "joelle", "nicky", "aaron", "serena", "daniel"]
        let bad = ["fred", "albert", "zarvox", "bells", "bad news", "cellos", "bahh", "novelty", "organ"]
        func score(_ v: AVSpeechSynthesisVoice) -> Int {
            var s = 0
            switch v.quality {          // iOS 17 target: .premium/.enhanced/.default all available
            case .premium: s += 30
            case .enhanced: s += 20
            default: break
            }
            if v.language == "en-US" { s += 4 } else if v.language == "en-GB" { s += 3 } else { s += 1 }
            let name = v.name.lowercased()
            if nice.contains(where: { name.contains($0) }) { s += 8 }
            if bad.contains(where: { name.contains($0) }) { s -= 40 }
            return s
        }
        return english.max { score($0) < score($1) }
    }
}

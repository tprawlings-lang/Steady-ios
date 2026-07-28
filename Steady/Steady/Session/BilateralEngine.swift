import Foundation
import AVFoundation
import CoreHaptics

/// Drives the non-visual channels of bilateral stimulation: alternating
/// left/right stereo tones and left/right haptic taps. This is the part a web
/// app can't do well — real stereo panning and Core Haptics.
///
/// The web app plays a 396 Hz tone panned hard left/right on each side change;
/// we reproduce that here and add a synchronized haptic transient.
final class BilateralEngine {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var toneBuffer: AVAudioPCMBuffer?
    private var hapticEngine: CHHapticEngine?
    private var audioReady = false

    init() {
        prepareAudio()
        prepareHaptics()
    }

    // MARK: Audio

    private func prepareAudio() {
        let session = AVAudioSession.sharedInstance()
        // .playback so tones are heard even with the ring/silent switch on;
        // sessions are an intentional foreground activity.
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true)

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        engine.attach(player)
        // Connect mono player to the stereo main mixer; we pan the player node.
        engine.connect(player, to: engine.mainMixerNode, format: format)
        toneBuffer = Self.makeTone(frequency: 396, seconds: 0.13, format: format)

        do {
            try engine.start()
            player.play()
            audioReady = true
        } catch {
            audioReady = false
        }
    }

    /// A short sine tone with a fast exponential decay envelope.
    private static func makeTone(frequency: Double, seconds: Double, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(sampleRate * seconds)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        guard let channel = buffer.floatChannelData?[0] else { return nil }
        let twoPiF = 2.0 * Double.pi * frequency
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let env = exp(-t * 22.0)               // fast decay, like the web's ramp-to-zero
            channel[i] = Float(sin(twoPiF * t) * env * 0.28)
        }
        return buffer
    }

    // MARK: Haptics

    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        hapticEngine = try? CHHapticEngine()
        hapticEngine?.isAutoShutdownEnabled = true
        try? hapticEngine?.start()
    }

    private func tap(intensity: Float) {
        guard let hapticEngine else { return }
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            ],
            relativeTime: 0
        )
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let p = try hapticEngine.makePlayer(with: pattern)
            try hapticEngine.start()
            try p.start(atTime: 0)
        } catch {
            // Haptics are best-effort; audio + visual carry the session.
        }
    }

    // MARK: Public

    /// Emit one bilateral cue. `side` is -1 (left) or +1 (right).
    func pulse(side: Int, sound: Bool, haptic: Bool) {
        let pan = side < 0 ? -1.0 : 1.0
        if sound, audioReady, let toneBuffer {
            player.pan = Float(pan)
            player.scheduleBuffer(toneBuffer, at: nil, options: .interrupts, completionHandler: nil)
        }
        if haptic {
            tap(intensity: 0.7)
        }
    }

    func stop() {
        player.stop()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    deinit { stop() }
}

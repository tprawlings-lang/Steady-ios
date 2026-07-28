import Foundation

/// Repeating alternating-side pulser for audio-only bilateral stimulation
/// (no moving dot). Mirrors the web `BlsAudio` interval of speedMs/2.
final class AudioPulser {
    private var timer: Timer?
    private var side = 1

    func start(speedMs: Double, haptic: Bool, pulse: @escaping (Int, Bool) -> Void) {
        stop()
        side = 1
        let interval = (speedMs / 2) / 1000.0
        pulse(side, haptic)          // fire immediately
        side *= -1
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            pulse(self.side, haptic)
            self.side *= -1
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit { stop() }
}

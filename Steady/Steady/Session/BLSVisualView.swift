import SwiftUI

/// Small reference holder so the animated view can remember the last side it
/// pulsed without triggering SwiftUI state churn on every frame.
final class SideTracker {
    var lastSide: Int = 0
    var startedAt: Date? = nil
}

/// The moving-dot bilateral stimulation, ported from the web canvas but native:
/// a `TimelineView(.animation)` + `Canvas` for buttery motion. On each left↔right
/// crossing it fires `onSide`, which the player uses to pulse audio/haptics —
/// keeping visual, audio, and haptic channels in perfect phase.
struct BLSVisualView: View {
    let running: Bool
    let speedMs: Double
    /// Called with -1 (left) or +1 (right) each time the dot crosses the midline.
    let onSide: (Int) -> Void

    @State private var tracker = SideTracker()

    var body: some View {
        TimelineView(.animation(paused: !running)) { timeline in
            Canvas { context, size in
                let w = size.width
                let h = size.height
                let inset: CGFloat = 44
                let cy = h / 2

                if running {
                    if tracker.startedAt == nil { tracker.startedAt = timeline.date }
                    let start = tracker.startedAt ?? timeline.date
                    let elapsedMs = timeline.date.timeIntervalSince(start) * 1000
                    let t = (elapsedMs.truncatingRemainder(dividingBy: speedMs)) / speedMs
                    let frac = 0.5 - 0.5 * cos(t * 2 * .pi)   // 0..1..0 ease
                    let x = inset + CGFloat(frac) * (w - inset * 2)
                    let side = x < w / 2 ? -1 : 1
                    if side != tracker.lastSide {
                        tracker.lastSide = side
                        let s = side
                        DispatchQueue.main.async { onSide(s) }   // defer side-effect out of render
                    }
                    drawDot(context, at: CGPoint(x: x, y: cy), color: .sage)
                } else {
                    tracker.startedAt = nil
                    tracker.lastSide = 0
                    drawDot(context, at: CGPoint(x: w / 2, y: cy), color: Color.sage.opacity(0.6))
                }
            }
        }
        .frame(height: 220)
        .background(Color.ground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityLabel(running ? "Bilateral stimulation: follow the moving dot with your eyes" : "Bilateral stimulation paused")
    }

    private func drawDot(_ context: GraphicsContext, at p: CGPoint, color: Color) {
        let r: CGFloat = 22
        let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
        context.fill(Circle().path(in: rect), with: .color(color))
        // Soft glow.
        let gr: CGFloat = 34
        let grect = CGRect(x: p.x - gr, y: p.y - gr, width: gr * 2, height: gr * 2)
        context.fill(Circle().path(in: grect), with: .color(color.opacity(0.18)))
    }
}

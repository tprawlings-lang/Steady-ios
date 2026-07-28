import Foundation

/// The recommended next step produced by the daily check-in — a faithful port
/// of `evaluateCheckin` from the web app's `lib/gating.ts`. The order of the
/// rules matters: the first matching rule wins.
enum RecommendedAction: String, Codable {
    /// Any harm urge or feeling unsafe → straight to crisis resources.
    case crisis
    /// High dissociation or very high activation/shutdown → grounding only.
    case groundingOnly
    /// Substance use, very poor sleep, or moderate dissociation → stabilization.
    case stabilization
    /// Cleared to do a processing/session module today.
    case processingOk

    var headline: String {
        switch self {
        case .crisis: return "Let's get you real support right now"
        case .groundingOnly: return "Grounding only today"
        case .stabilization: return "Stabilization today, not processing"
        case .processingOk: return "You're clear for a session today"
        }
    }

    var detail: String {
        switch self {
        case .crisis:
            return "Based on your check-in, the right next step is a real person, not a session. Crisis resources are one tap away."
        case .groundingOnly:
            return "You're quite activated or disconnected right now. Sessions are paused for today — grounding and your calm place are the safe path."
        case .stabilization:
            return "Today is for steadying skills — calm place, containment, body scan — rather than trauma processing."
        case .processingOk:
            return "Your check-in looks steady. You can do any module your program has opened."
        }
    }
}

struct CheckinAnswers {
    /// 0–10, higher = more activated.
    var activation: Int = 0
    /// 0–10, higher = more shut down.
    var shutdown: Int = 0
    /// Any urge to harm self or others today.
    var harmUrge: Bool = false
    /// Feels safe where they are.
    var feelsSafe: Bool = true
    /// 0–10, higher = more disconnected/unreal.
    var dissociation: Int = 0
    /// 0–10, higher = slept better.
    var sleepQuality: Int = 5
    /// Alcohol/drug use that could affect a session.
    var substanceFlag: Bool = false
}

enum Checkin {
    /// Deterministic mapping from a check-in to today's safest action.
    /// Faithful port of `evaluateCheckin` (lib/gating.ts). Rule order is load-bearing.
    static func evaluate(_ c: CheckinAnswers) -> RecommendedAction {
        if c.harmUrge || !c.feelsSafe { return .crisis }
        if c.dissociation >= 7 { return .groundingOnly }
        if c.activation >= 8 || c.shutdown >= 8 { return .groundingOnly }
        if c.substanceFlag || c.sleepQuality <= 2 || c.dissociation >= 4 { return .stabilization }
        return .processingOk
    }
}

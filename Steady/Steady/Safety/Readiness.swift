import Foundation

/// Deterministic readiness scoring — a faithful port of `scoreReadiness`
/// (lib/safety/readiness.ts). The *caps* are the real safety mechanism; the
/// precise score→track boundaries are provisional. Pure and side-effect-free.
struct ReadinessDomains {
    var stability: Double        // 0–10
    var bodySafety: Double       // 0–10
    var presentConnection: Double // 0–10
    var symptomIntensity: Double // 0–10 (higher = worse)
    var sleep: Double            // 0–10
    var support: Double          // 0–10
    var selfReadiness: Double    // 0–10
    var pauseCapacity: Double    // 0–10
    var feelsFullySafe: Bool
    var riskFlag: Bool
}

enum ReadinessTrack: String, Codable {
    case grounding
    case cautious
    case steady

    var label: String {
        switch self {
        case .grounding: return "Grounding"
        case .cautious: return "Cautious"
        case .steady: return "Steady"
        }
    }
}

struct ReadinessResult {
    /// Provisional 0–100 score.
    let score: Int
    let track: ReadinessTrack
    /// Engine-facing caps (the real safety mechanism).
    let riskCap: Bool
    let lessThanFullySafeCap: Bool
    let pauseCapacityCap: Bool
}

enum Readiness {
    private static func clamp10(_ n: Double) -> Double { max(0, min(10, n)) }

    static func score(_ d: ReadinessDomains) -> ReadinessResult {
        // Appendix multiplier form (weights sum to 10 → 0–100 range).
        let raw =
            clamp10(d.stability) * 1.5 +
            clamp10(d.bodySafety) * 1.5 +
            clamp10(d.presentConnection) * 1.0 +
            (10 - clamp10(d.symptomIntensity)) * 1.5 +
            clamp10(d.sleep) * 1.0 +
            clamp10(d.support) * 1.0 +
            clamp10(d.selfReadiness) * 1.5 +
            clamp10(d.pauseCapacity) * 1.0

        let riskCap = d.riskFlag == true
        let lessThanFullySafeCap = d.feelsFullySafe == false
        let pauseCapacityCap = clamp10(d.pauseCapacity) <= 2

        // Caps override the formula — never remove a cap to credit other strengths.
        var s = raw
        if riskCap { s = 0 }
        if lessThanFullySafeCap { s = min(s, 30) }
        if pauseCapacityCap { s = min(s, 60) }

        let track: ReadinessTrack = s <= 30 ? .grounding : (s <= 60 ? .cautious : .steady)
        return ReadinessResult(
            score: Int(s.rounded()),
            track: track,
            riskCap: riskCap,
            lessThanFullySafeCap: lessThanFullySafeCap,
            pauseCapacityCap: pauseCapacityCap
        )
    }
}

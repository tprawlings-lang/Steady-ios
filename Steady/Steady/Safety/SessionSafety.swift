import Foundation

/// In-session safety rules — a faithful native port of the web app's
/// `lib/session-safety.ts`. These are deterministic rules-engine decisions,
/// never model judgment, and they are the core safety mechanism of the app.
/// Any change here must keep `SessionSafetyTests` green.
enum SessionSafety {
    /// Distress rating (SUDS) that pauses processing for grounding + an explicit choice.
    static let sudsPauseAt = 8
    /// Distress rating that ends the session outright (stricter than the pause floor).
    static let sudsHardStopAt = 9
    /// Mid-session rise (vs. session start) that triggers the pause flow.
    static let sudsRisePause = 3
    /// Post-session rating that puts processing modules on a 24h cooldown.
    static let sudsCooldownAt = 8

    /// Session wind-down begins at 35 minutes; hard cap at 45.
    static let sessionWinddownMin = 35
    static let sessionCapMin = 45

    /// Rest pause inserted between bilateral-stimulation sets (seconds).
    static let restSeconds = 8

    enum SudsDecision {
        case cont
        case pause
        case hardStop
    }

    /// Decide what happens after a mid-session distress rating.
    /// `trail` is all ratings so far in the session, including the current one last.
    static func sudsDecision(_ trail: [Int]) -> SudsDecision {
        guard let current = trail.last else { return .cont }
        let start = trail[0]
        if current >= sudsHardStopAt { return .hardStop }
        if current >= sudsPauseAt { return .pause }
        if trail.count > 1 && current - start >= sudsRisePause { return .pause }
        return .cont
    }
}

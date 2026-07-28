import Foundation

/// Deterministic directive cues spoken DURING a positive-resource (calm-place)
/// bilateral set — personalized to the member's own place. A faithful port of
/// the web `personalizedCues`. Positive-resource only: these are used only for
/// `.autonomous`-tier modules, never for gated trauma-processing sets where
/// "notice what's pleasant" would be clinically wrong.
enum ResourcingCues {
    /// Normalize a member-typed place for safe re-use in a spoken/shown line:
    /// single line, collapsed whitespace, length-capped, no markup characters.
    static func sanitize(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "" }
        let cleaned = raw
            .replacingOccurrences(of: "[\\r\\n\\t<>{}]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        return String(cleaned.prefix(40))
    }

    /// Cues personalized to the member's place; generic fallback when empty.
    /// Same fixed templates as the web (guard-clean, positive-resource only).
    static func cues(place: String?) -> [String] {
        let p = sanitize(place)
        guard !p.isEmpty else {
            return [
                "Stay with your calm place.",
                "Notice what's pleasant here.",
                "Let it be as clear as it wants to be.",
                "Breathe.",
                "Your word, and this place.",
            ]
        }
        return [
            "Stay with \(p).",
            "Notice what's pleasant here.",
            "Let \(p) be as clear as it wants to be.",
            "Breathe.",
            "Your word, and \(p).",
        ]
    }
}

import Foundation

/// Region-aware crisis resources — a port of `lib/crisis-resources.ts`.
/// Numbers change and services sunset; each region carries a last-verified date.
/// OWNER: founder (until a safety owner is named). NEXT REVIEW DUE: 2026-09-01.
struct CrisisResource: Identifiable, Hashable {
    var id: String { label }
    let label: String
    /// tel: / sms: / https: link — rendered as tap-to-call / tap-to-text.
    let href: String
    var detail: String? = nil
}

struct CrisisRegion: Identifiable, Hashable {
    var id: String { code }
    let code: String
    let name: String
    let emergencyLine: String
    let lastVerified: String
    let resources: [CrisisResource]
}

enum CrisisData {
    static let regions: [CrisisRegion] = [
        CrisisRegion(
            code: "US", name: "United States",
            emergencyLine: "In immediate danger? Call 911",
            lastVerified: "2026-06-10",
            resources: [
                CrisisResource(label: "Call 988 — Suicide & Crisis Lifeline", href: "tel:988"),
                CrisisResource(label: "Text 988", href: "sms:988"),
                CrisisResource(label: "Crisis Text Line — text HOME to 741741", href: "sms:741741&body=HOME")
            ]
        ),
        CrisisRegion(
            code: "UK", name: "United Kingdom",
            emergencyLine: "In immediate danger? Call 999",
            lastVerified: "2026-06-10",
            resources: [
                CrisisResource(label: "Samaritans — call 116 123 (free, 24/7)", href: "tel:116123")
            ]
        ),
        CrisisRegion(
            code: "CA", name: "Canada",
            emergencyLine: "In immediate danger? Call 911",
            lastVerified: "2026-06-10",
            resources: [
                CrisisResource(label: "Call or text 988 — Suicide Crisis Helpline", href: "tel:988")
            ]
        ),
        CrisisRegion(
            code: "AU", name: "Australia",
            emergencyLine: "In immediate danger? Call 000",
            lastVerified: "2026-06-10",
            resources: [
                CrisisResource(label: "Lifeline — call 13 11 14 (24/7)", href: "tel:131114")
            ]
        )
    ]

    static let fallback = CrisisResource(
        label: "Anywhere else: find a helpline in your country",
        href: "https://findahelpline.com",
        detail: "findahelpline.com lists free, confidential support lines worldwide — or call your local emergency number."
    )

    /// Honesty rule (compliance 4C.4): shown wherever crisis resources appear.
    static let notMonitoredLine =
        "Steady is not monitored in real time — no one from Steady will see this or respond. Please use the resources above to reach a real person now."
}

import Foundation

/// Codable mirrors of the Autopilot API (/api/mobile/v1/autopilot/today).
/// The plan is null for non-Premium members.
struct AutopilotItemDTO: Codable, Hashable {
    let kind: String      // checkin | practice | session | lesson | ground
    let title: String
    let detail: String
    let href: String
}

struct AutopilotPlanDTO: Codable, Hashable {
    let date: String
    let headline: String
    let pacingNote: String?
    let items: [AutopilotItemDTO]
    let outreach: String?
}

struct AutopilotTodayResponse: Codable {
    let plan: AutopilotPlanDTO?
}

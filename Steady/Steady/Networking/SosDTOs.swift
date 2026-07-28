import Foundation

/// Codable mirror of the SOS panic panel API (/api/mobile/v1/sos). Every field
/// but the crisis line may be absent for a member who hasn't filled in a plan.
struct SosPanelDTO: Codable {
    let calmPlace: String?
    let reminderPhrase: String?
    let groundingTools: [String]
    let supportContactName: String?
    let supportContactMethod: String?
    let crisisLabel: String
    let crisisHref: String
}

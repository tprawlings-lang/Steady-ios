import Foundation

/// Codable mirrors for the in-session live-voice endpoints.

struct VoiceInfo: Codable {
    let version: String
    let sections: [ConsentSection]   // reuses the ConsentSection {title, body} DTO
    let granted: Bool
    let available: Bool
}

/// The deterministic (optionally AI-reworded) spoken response from the session
/// responder. `suggestGroundMe` is a UI hint only — the session's stop rules are
/// independent and enforced client-side.
struct SessionResponseDTO: Codable, Equatable {
    let text: String
    let kind: String                 // crisis | ground | technique | acknowledge
    let suggestGroundMe: Bool
    let crisis: Bool
    let source: String?              // deterministic | ai
    let aiEligible: Bool?
}

struct SpeakResponse: Codable {
    let ok: Bool
    let error: String?
    let response: SessionResponseDTO?
}

import Foundation

/// Codable mirror of the practices content API (/api/mobile/v1/practices).
struct BreathPhaseDTO: Codable, Hashable {
    let label: String   // inhale | hold | exhale | rest
    let seconds: Double
}

/// One spoken/shown beat of a guided meditation (roadmap F2). Optional on
/// PracticeDTO — present only for `type == "meditation"`.
struct MeditationSegmentDTO: Codable, Hashable {
    let text: String
    let seconds: Double
}

struct PracticeDTO: Codable, Identifiable, Hashable {
    let id: String
    let type: String
    let title: String
    let intro: String
    let durationSec: Double
    let intensity: Int
    let tags: [String]
    let phases: [BreathPhaseDTO]?
    let segments: [MeditationSegmentDTO]?
    let hasHold: Bool
    let note: String?
}

struct PracticesResponse: Codable { let practices: [PracticeDTO] }

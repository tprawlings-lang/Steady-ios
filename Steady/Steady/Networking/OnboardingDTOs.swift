import Foundation

/// Codable mirrors for the onboarding pipeline endpoints.

struct SignupBody: Codable {
    let name: String
    let email: String
    let password: String
    let dob: String          // YYYY-MM-DD
    let wellnessAck: Bool
}

struct ConsentSection: Codable, Identifiable, Equatable {
    var id: String { title }
    let title: String
    let body: String
}
struct ConsentInfo: Codable { let version: String; let sections: [ConsentSection] }

struct ScreenerItem: Codable, Identifiable, Equatable {
    let id: String
    let text: String
    let onYes: String
    let note: String?
}
struct ScreenerInfo: Codable { let version: String; let items: [ScreenerItem] }

struct FitnessStateDTO: Codable { let status: String; let retakeInHours: Int? }
struct ScreenerResult: Codable {
    let outcome: String          // pass | soft_flag | hard_stop
    let flags: [String]
    let state: FitnessStateDTO
}

struct ScaleOptionDTO: Codable, Equatable, Hashable { let value: Int; let label: String }
struct InstrumentSectionDTO: Codable, Equatable { let startIndex: Int; let heading: String }
struct RiskItemDTO: Codable, Equatable { let index: Int; let threshold: Int; let flag: String }

struct InstrumentDTO: Codable, Identifiable, Equatable {
    let id: String
    let version: String
    let title: String
    let intro: String
    let options: [ScaleOptionDTO]
    let items: [String]
    let sections: [InstrumentSectionDTO]?
    let riskItems: [RiskItemDTO]?
    let cutoff: Int
    let cutoffNote: String
}
struct MeasuresInfo: Codable { let instruments: [InstrumentDTO]; let completed: [String] }
struct MeasureResult: Codable { let total: Int; let positive: Bool; let riskFlags: [String]; let crisis: Bool }

struct ReadinessResultDTO: Codable { let score: Int; let track: String; let crisis: Bool }

/// The server-driven option catalog for the profile forms.
struct Labeled: Codable, Identifiable, Equatable, Hashable {
    var id: String { value }
    let value: String
    let label: String
}
struct ProfileCatalog: Codable {
    let goals: [String]
    let therapistStatus: [Labeled]
    let emdrExperience: [Labeled]
    let traumaAreas: [String]
    let triggerCategories: [Labeled]
    let warningSigns: [String]
    let triggerResponses: [String]
    let safetyTools: [String]
    let tones: [String]
    let companionModes: [String]
    let companionAvoidances: [String]
    let sleep: [Labeled]
    let support: [Labeled]
    let processing: [Labeled]
    let pause: [Labeled]
    let pace: [Labeled]
    let risk: [Labeled]
}

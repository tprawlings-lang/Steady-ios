import Foundation

/// Codable mirrors of the mobile JSON API contract
/// (`/api/mobile/v1/...` in the Next.js app).

struct UserDTO: Codable, Equatable {
    let id: String
    let email: String
    let name: String
    let role: String
}

struct LoginResponse: Codable {
    let token: String
    let user: UserDTO
}

struct TodayCheckinDTO: Codable, Equatable {
    let date: String
    let action: String
}

struct GatingDTO: Codable, Equatable {
    let subscriptionActive: Bool
    let hasConsent: Bool
    let screeningComplete: Bool
    let profileComplete: Bool
    let fitnessStatus: String
    let retakeInHours: Int?
    let seizureFlag: Bool
    let liveVoiceAvailable: Bool
    let nextStep: String
    let todayCheckin: TodayCheckinDTO?
    let calmPlace: String?
}

struct ModuleDTO: Codable, Identifiable, Equatable {
    let id: String
    let order: Int
    let name: String
    let tier: String
    let objective: String
    let durationLabel: String
    let allowed: Bool
    let reason: String?
    let action: String?
}

struct MeResponse: Codable {
    let user: UserDTO
    let gating: GatingDTO
    let modules: [ModuleDTO]
}

struct CheckinResultDTO: Codable {
    let action: String
    let date: String
}

/// A check-in row as returned by GET /checkins (SQLite integers for booleans).
struct CheckinRowDTO: Codable {
    let checkin_date: String
    let activation: Int
    let shutdown: Int
    let harm_urge: Int
    let feels_safe: Int
    let dissociation: Int
    let sleep_quality: Int
    let substance_flag: Int
    let recommended_action: String
}

struct CheckinsResponse: Codable { let checkins: [CheckinRowDTO] }

/// A session row as returned by GET /sessions.
struct SessionRowDTO: Codable {
    let id: String
    let module_id: String
    let status: String
    let pre_suds: Int?
    let post_suds: Int?
    let peak_suds: Int?
    let hard_stop_reason: String?
    let detail_json: String?
    let started_at: String?
    let ended_at: String?
}

struct SessionsResponse: Codable { let sessions: [SessionRowDTO] }

struct StartSessionResponse: Codable { let sessionId: String }

/// Body for POST /checkins.
struct CheckinBody: Codable {
    let activation: Int
    let shutdown: Int
    let harm_urge: Bool
    let feels_safe: Bool
    let dissociation: Int
    let sleep_quality: Int
    let substance_flag: Bool
}

/// A denial returned by POST /sessions/start when a gate isn't satisfied.
struct GateDenial: Codable, Error { let error: String; let action: String? }

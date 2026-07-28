import Foundation
import SwiftData

/// A completed (or stopped) session, persisted on-device via SwiftData.
@Model
final class SessionRecord {
    var moduleId: String
    var moduleName: String
    var startedAt: Date
    /// "completed" | "hard_stop" | "abandoned"
    var outcome: String
    var preSuds: Int?
    var postSuds: Int?
    var peakSuds: Int?
    /// Full distress trail, stored as JSON-encoded [Int] for portability.
    var sudsTrailData: Data
    var focus: String?
    var hardStopReason: String?
    /// Server-side id once this session has been recorded to the shared backend.
    /// nil = local-only (created offline / backend disabled).
    var remoteId: String?

    init(moduleId: String, moduleName: String, startedAt: Date, outcome: String,
         preSuds: Int?, postSuds: Int?, peakSuds: Int?, sudsTrail: [Int],
         focus: String?, hardStopReason: String?, remoteId: String? = nil) {
        self.moduleId = moduleId
        self.moduleName = moduleName
        self.startedAt = startedAt
        self.outcome = outcome
        self.preSuds = preSuds
        self.postSuds = postSuds
        self.peakSuds = peakSuds
        self.sudsTrailData = (try? JSONEncoder().encode(sudsTrail)) ?? Data()
        self.focus = focus
        self.hardStopReason = hardStopReason
        self.remoteId = remoteId
    }

    var sudsTrail: [Int] {
        (try? JSONDecoder().decode([Int].self, from: sudsTrailData)) ?? []
    }
}

/// A daily readiness check-in, persisted on-device.
@Model
final class CheckinRecord {
    var date: Date
    var action: String   // RecommendedAction.rawValue
    var activation: Int
    var shutdown: Int
    var harmUrge: Bool
    var feelsSafe: Bool
    var dissociation: Int
    var sleepQuality: Int
    var substanceFlag: Bool
    /// Whether this check-in has been pushed to the shared backend.
    var synced: Bool

    init(date: Date, action: String, activation: Int, shutdown: Int, harmUrge: Bool,
         feelsSafe: Bool, dissociation: Int, sleepQuality: Int, substanceFlag: Bool,
         synced: Bool = false) {
        self.date = date
        self.action = action
        self.activation = activation
        self.shutdown = shutdown
        self.harmUrge = harmUrge
        self.feelsSafe = feelsSafe
        self.dissociation = dissociation
        self.sleepQuality = sleepQuality
        self.substanceFlag = substanceFlag
        self.synced = synced
    }
}

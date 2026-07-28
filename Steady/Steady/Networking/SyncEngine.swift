import Foundation
import SwiftData

/// Reconciles the shared backend with the on-device SwiftData cache.
///
/// Design: local-first. The session player and check-in always write locally so
/// the app works offline and the safety rules never wait on the network. Sync
/// then (a) pushes anything created offline and (b) pulls the account's history
/// from the server so a session done on the web shows up on the phone.
@MainActor
enum SyncEngine {
    private static let sqlFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// Full reconcile: push pending, then pull server history.
    static func sync(_ backend: Backend, context: ModelContext) async {
        guard backend.isAuthenticated else { return }
        await flushPendingCheckins(backend, context: context)
        await pull(backend, context: context)
        try? await backend.loadMe()   // refresh gating + module access
    }

    // MARK: Push

    static func flushPendingCheckins(_ backend: Backend, context: ModelContext) async {
        let pending = (try? context.fetch(FetchDescriptor<CheckinRecord>(
            predicate: #Predicate { $0.synced == false }))) ?? []
        for c in pending {
            let body = CheckinBody(
                activation: c.activation, shutdown: c.shutdown,
                harm_urge: c.harmUrge, feels_safe: c.feelsSafe,
                dissociation: c.dissociation, sleep_quality: c.sleepQuality,
                substance_flag: c.substanceFlag)
            if (try? await backend.postCheckin(body)) != nil {
                c.synced = true
            }
        }
        try? context.save()
    }

    // MARK: Pull

    static func pull(_ backend: Backend, context: ModelContext) async {
        if let sessions = try? await backend.getSessions() {
            for s in sessions where s.status != "in_progress" {
                upsertSession(s, context: context)
            }
        }
        if let checkins = try? await backend.getCheckins() {
            for c in checkins { upsertCheckin(c, context: context) }
        }
        try? context.save()
    }

    private static func upsertSession(_ dto: SessionRowDTO, context: ModelContext) {
        let rid = dto.id
        let existing = (try? context.fetch(FetchDescriptor<SessionRecord>(
            predicate: #Predicate { $0.remoteId == rid }))) ?? []
        guard existing.isEmpty else { return }   // already have it locally

        let started = dto.started_at.flatMap { sqlFormatter.date(from: $0) } ?? Date()
        var trail: [Int] = []
        if let json = dto.detail_json, let data = json.data(using: .utf8) {
            let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            if let arr = obj?["sudsTrail"] as? [Int] { trail = arr }
        }
        let module = ModuleCatalog.module(id: dto.module_id)
        let record = SessionRecord(
            moduleId: dto.module_id,
            moduleName: module?.name ?? dto.module_id,
            startedAt: started, outcome: dto.status,
            preSuds: dto.pre_suds, postSuds: dto.post_suds, peakSuds: dto.peak_suds,
            sudsTrail: trail, focus: nil, hardStopReason: dto.hard_stop_reason,
            remoteId: rid)
        context.insert(record)
    }

    private static func upsertCheckin(_ dto: CheckinRowDTO, context: ModelContext) {
        guard let day = dayFormatter.date(from: dto.checkin_date) else { return }
        // One check-in per calendar day; server wins for that day.
        let lower = Calendar.current.startOfDay(for: day)
        let upper = Calendar.current.date(byAdding: .day, value: 1, to: lower) ?? day
        let existing = (try? context.fetch(FetchDescriptor<CheckinRecord>(
            predicate: #Predicate { $0.date >= lower && $0.date < upper }))) ?? []
        for old in existing { context.delete(old) }
        let record = CheckinRecord(
            date: day, action: dto.recommended_action,
            activation: dto.activation, shutdown: dto.shutdown,
            harmUrge: dto.harm_urge != 0, feelsSafe: dto.feels_safe != 0,
            dissociation: dto.dissociation, sleepQuality: dto.sleep_quality,
            substanceFlag: dto.substance_flag != 0, synced: true)
        context.insert(record)
    }
}

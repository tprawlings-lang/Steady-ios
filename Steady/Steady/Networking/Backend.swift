import Foundation
import Observation

enum APIError: LocalizedError {
    case notConfigured
    case http(status: Int, message: String)
    case decoding
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "No server is configured."
        case .http(_, let m): return m
        case .decoding: return "Unexpected response from the server."
        case .transport(let m): return m
        }
    }
}

/// The single coordinator for talking to the Steady backend. When no server URL
/// is configured, the app runs fully on-device (the original standalone mode).
/// Once a server is set and the member signs in, check-ins and sessions sync to
/// the shared account so the website and the phone stay in step.
@MainActor
@Observable
final class Backend {
    var baseURLString: String {
        didSet { UserDefaults.standard.set(baseURLString, forKey: Keys.baseURL) }
    }
    var currentUser: UserDTO?
    var gating: GatingDTO?
    var serverModules: [ModuleDTO] = []
    var lastError: String?

    private var token: String?
    private let session = URLSession(configuration: .default)

    private enum Keys { static let baseURL = "steady.server.baseURL" }

    init() {
        baseURLString = UserDefaults.standard.string(forKey: Keys.baseURL) ?? ""
        token = Keychain.loadToken()
    }

    var isConfigured: Bool { URL(string: baseURLString.trimmingCharacters(in: .whitespaces))?.scheme != nil }
    var hasToken: Bool { token != nil }
    var isAuthenticated: Bool { token != nil && currentUser != nil }

    /// Server-governed access for a module, if we have it. nil → fall back to
    /// the local (tier-based) rule.
    func serverAllows(_ moduleId: String) -> Bool? {
        guard isAuthenticated, !serverModules.isEmpty else { return nil }
        return serverModules.first { $0.id == moduleId }?.allowed
    }

    func serverReason(_ moduleId: String) -> String? {
        serverModules.first { $0.id == moduleId }?.reason
    }

    // MARK: - Auth

    func login(email: String, password: String) async throws {
        let body = try JSONEncoder().encode(["email": email, "password": password])
        let resp: LoginResponse = try await request("/api/mobile/v1/auth/login", method: "POST", body: body, authed: false)
        token = resp.token
        Keychain.save(token: resp.token)
        currentUser = resp.user
        try await loadMe()
    }

    func loadMe() async throws {
        let me: MeResponse = try await request("/api/mobile/v1/me", method: "GET")
        currentUser = me.user
        gating = me.gating
        serverModules = me.modules
    }

    /// Restore a prior session on launch. Returns true if a valid token loaded.
    @discardableResult
    func restore() async -> Bool {
        guard isConfigured, token != nil else { return false }
        do { try await loadMe(); return true }
        catch { logout(); return false }
    }

    func logout() {
        token = nil
        currentUser = nil
        gating = nil
        serverModules = []
        Keychain.clear()
    }

    // MARK: - Onboarding pipeline

    func signup(name: String, email: String, password: String, dob: String, wellnessAck: Bool) async throws {
        let body = try JSONEncoder().encode(SignupBody(name: name, email: email, password: password, dob: dob, wellnessAck: wellnessAck))
        let resp: LoginResponse = try await request("/api/mobile/v1/auth/signup", method: "POST", body: body, authed: false)
        token = resp.token
        Keychain.save(token: resp.token)
        currentUser = resp.user
        try await loadMe()
    }

    struct SubscribeResult: Codable { let active: Bool }
    @discardableResult
    func subscribe() async throws -> Bool {
        let r: SubscribeResult = try await request("/api/mobile/v1/billing/subscribe", method: "POST", body: Data("{}".utf8))
        try await loadMe()
        return r.active
    }

    func getConsent() async throws -> ConsentInfo {
        try await request("/api/mobile/v1/consent", method: "GET")
    }
    func grantConsent() async throws {
        let _: OkResponse = try await request("/api/mobile/v1/consent", method: "POST", body: Data("{}".utf8))
        try await loadMe()
    }

    func getScreener() async throws -> ScreenerInfo {
        try await request("/api/mobile/v1/screener", method: "GET")
    }
    func submitScreener(_ answers: [String: Bool]) async throws -> ScreenerResult {
        let body = try JSONEncoder().encode(["answers": answers])
        let r: ScreenerResult = try await request("/api/mobile/v1/screener", method: "POST", body: body)
        try await loadMe()
        return r
    }

    func getMeasures() async throws -> MeasuresInfo {
        try await request("/api/mobile/v1/measures", method: "GET")
    }
    struct MeasureBody: Encodable { let instrument: String; let answers: [Int] }
    func submitMeasure(instrument: String, answers: [Int]) async throws -> MeasureResult {
        let body = try JSONEncoder().encode(MeasureBody(instrument: instrument, answers: answers))
        let r: MeasureResult = try await request("/api/mobile/v1/measures", method: "POST", body: body)
        try await loadMe()
        return r
    }

    func getProfileCatalog() async throws -> ProfileCatalog {
        try await request("/api/mobile/v1/profile", method: "GET")
    }
    /// Post one profile step. `body` must include a "step" key.
    private func profilePost<T: Encodable, R: Decodable>(_ body: T) async throws -> R {
        let data = try JSONEncoder().encode(body)
        let r: R = try await request("/api/mobile/v1/profile", method: "POST", body: data)
        try await loadMe()
        return r
    }
    func profileStep<T: Encodable>(_ body: T) async throws {
        let _: OkResponse = try await profilePost(body)
    }
    func profileReadiness<T: Encodable>(_ body: T) async throws -> ReadinessResultDTO {
        try await profilePost(body)
    }

    // MARK: - Sync endpoints

    func postCheckin(_ body: CheckinBody) async throws -> CheckinResultDTO {
        let data = try JSONEncoder().encode(body)
        return try await request("/api/mobile/v1/checkins", method: "POST", body: data)
    }

    func getCheckins(since: String? = nil) async throws -> [CheckinRowDTO] {
        let q = since.map { "?since=\($0)" } ?? ""
        let r: CheckinsResponse = try await request("/api/mobile/v1/checkins\(q)", method: "GET")
        return r.checkins
    }

    /// Start a server session (enforces gating). Throws `GateDenial` on 403.
    func startSession(moduleId: String, focus: String?) async throws -> String {
        var payload: [String: String] = ["moduleId": moduleId]
        if let focus, !focus.isEmpty { payload["focus"] = focus }
        let body = try JSONEncoder().encode(payload)
        let r: StartSessionResponse = try await request("/api/mobile/v1/sessions/start", method: "POST", body: body)
        return r.sessionId
    }

    func finishSession(sessionId: String, outcome: String, preSuds: Int?, postSuds: Int?,
                       peakSuds: Int?, hardStopReason: String?, sudsTrail: [Int]) async throws {
        struct Body: Encodable {
            let sessionId: String; let outcome: String
            let preSuds: Int?; let postSuds: Int?; let peakSuds: Int?
            let hardStopReason: String?; let sudsTrail: [Int]
        }
        let body = try JSONEncoder().encode(Body(sessionId: sessionId, outcome: outcome,
            preSuds: preSuds, postSuds: postSuds, peakSuds: peakSuds,
            hardStopReason: hardStopReason, sudsTrail: sudsTrail))
        let _: OkResponse = try await request("/api/mobile/v1/sessions/finish", method: "POST", body: body)
    }

    func getSessions(since: String? = nil) async throws -> [SessionRowDTO] {
        let q = since.map { "?since=\($0)" } ?? ""
        let r: SessionsResponse = try await request("/api/mobile/v1/sessions\(q)", method: "GET")
        return r.sessions
    }

    /// Best-effort safety telemetry — never throws into the session flow.
    func postSafetyEvent(type: String, sessionId: String?) async {
        var payload: [String: String] = ["type": type]
        if let sessionId { payload["sessionId"] = sessionId }
        guard let body = try? JSONEncoder().encode(payload) else { return }
        let _: OkResponse? = try? await request("/api/mobile/v1/safety-events", method: "POST", body: body)
    }

    // MARK: - Companion

    func companionConversation() async throws -> ConversationResponse {
        try await request("/api/mobile/v1/companion/conversation", method: "GET")
    }
    func openDailyChat() async throws -> DailyChatResponse {
        try await request("/api/mobile/v1/companion/daily", method: "POST", body: Data("{}".utf8))
    }
    struct MessageBody: Encodable { let conversationId: String?; let text: String; let contextType: String }
    func sendCompanionMessage(conversationId: String?, text: String, contextType: String = "general") async throws -> SendMessageResponse {
        let body = try JSONEncoder().encode(MessageBody(conversationId: conversationId, text: text, contextType: contextType))
        return try await request("/api/mobile/v1/companion/message", method: "POST", body: body)
    }
    func getMemory() async throws -> MemoryListResponse {
        try await request("/api/mobile/v1/companion/memory", method: "GET")
    }
    struct MemoryActionBody: Encodable { let action: String; let enabled: String?; let itemId: String? }
    func memoryAction(_ action: String, enabled: String? = nil, itemId: String? = nil) async throws -> MemoryListResponse {
        let body = try JSONEncoder().encode(MemoryActionBody(action: action, enabled: enabled, itemId: itemId))
        return try await request("/api/mobile/v1/companion/memory", method: "POST", body: body)
    }

    // MARK: - In-session live voice

    func getVoiceInfo() async throws -> VoiceInfo {
        try await request("/api/mobile/v1/voice/consent", method: "GET")
    }
    func setVoiceConsent(grant: Bool) async throws -> VoiceInfo {
        let body = try JSONEncoder().encode(["action": grant ? "grant" : "withdraw"])
        return try await request("/api/mobile/v1/voice/consent", method: "POST", body: body)
    }
    struct SpeakBody: Encodable {
        let sessionId: String; let moduleId: String; let transcript: String
        let currentSuds: Int?; let calmPlace: String?; let name: String?
    }
    func speakInSession(sessionId: String, moduleId: String, transcript: String,
                        currentSuds: Int?, calmPlace: String?, name: String?) async throws -> SpeakResponse {
        let body = try JSONEncoder().encode(SpeakBody(
            sessionId: sessionId, moduleId: moduleId, transcript: transcript,
            currentSuds: currentSuds, calmPlace: calmPlace, name: name))
        return try await request("/api/mobile/v1/sessions/speak", method: "POST", body: body)
    }

    // MARK: - Core request

    private struct OkResponse: Codable { let ok: Bool }
    private struct ServerError: Codable { let error: String; let action: String? }

    private func request<T: Decodable>(_ path: String, method: String,
                                       body: Data? = nil, authed: Bool = true) async throws -> T {
        guard isConfigured, let url = URL(string: baseURLString.trimmingCharacters(in: .whitespaces) + path) else {
            throw APIError.notConfigured
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authed, let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.httpBody = body

        let data: Data, response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.decoding }

        if !(200...299).contains(http.statusCode) {
            // Surface the gate action on 403 so the UI can guide the member.
            if http.statusCode == 403, let denial = try? JSONDecoder().decode(ServerError.self, from: data) {
                throw GateDenial(error: denial.error, action: denial.action)
            }
            let msg = (try? JSONDecoder().decode(ServerError.self, from: data))?.error
                ?? "Request failed (\(http.statusCode))."
            if http.statusCode == 401 { logout() }
            throw APIError.http(status: http.statusCode, message: msg)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }
}
